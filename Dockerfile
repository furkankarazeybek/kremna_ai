# 1. Aşama: Backend ve Frontend'leri Build Et
FROM node:20-slim AS builder

# Backend Build
WORKDIR /app/backend
COPY dashboard_backend/package*.json ./
RUN npm install
COPY dashboard_backend/ .
RUN npm run build

# Dashboard Frontend Build
WORKDIR /app/frontend
COPY dashboard_frontend/package*.json ./
RUN npm install
COPY dashboard_frontend/ .
ENV REACT_APP_API_URL=/api/v1
RUN npm run build

# Widget Build
WORKDIR /app/widget
COPY chatbot_widget/package*.json ./
RUN npm install
COPY chatbot_widget/ .
RUN npm run build

# 2. Aşama: Çalıştırma Ortamı
FROM node:20-slim

# PostgreSQL, Nginx, Supervisor VE Netcat kurulumu
# (netcat-openbsd paketini ekledik)
RUN apt-get update && apt-get install -y postgresql postgresql-contrib nginx supervisor netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Uygulama dosyalarını kopyala
WORKDIR /app
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/node_modules ./backend/node_modules
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/frontend/build /usr/share/nginx/html/dashboard
COPY --from=builder /app/widget/dist /usr/share/nginx/html/widget

# PostgreSQL Ayarları
USER postgres
RUN /etc/init.d/postgresql start && \
    psql --command "CREATE USER kuser WITH SUPERUSER PASSWORD 'kpass';" && \
    createdb -O kuser dashboard_db
USER root

# Nginx Yapılandırması (Tüm portları 7860'a topluyoruz)
RUN echo 'server { \
    listen 7860; \
    location / { \
        root /usr/share/nginx/html/dashboard; \
        try_files $uri $uri/ /index.html; \
    } \
    location /widget { \
        alias /usr/share/nginx/html/widget; \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/v1 { \
        proxy_pass http://localhost:3000; \
    } \
    location /socket.io { \
        proxy_pass http://localhost:3000; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "Upgrade"; \
    } \
}' > /etc/nginx/sites-available/default

# Supervisord ile tüm servisleri yönet
# (Backend komutuna veritabanını beklemesi için kontrol ekledik)
RUN echo '[supervisord] \n\
nodaemon=true \n\
[program:postgres] \n\
command=/bin/bash -c "rm -f /var/lib/postgresql/15/main/postmaster.pid && /usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main -c config_file=/etc/postgresql/15/main/postgresql.conf" \n\
user=postgres \n\
autorestart=true \n\
[program:backend] \n\
command=/bin/bash -c "until nc -z localhost 5432; do echo Waiting for DB...; sleep 1; done; node /app/backend/dist/main.js" \n\
directory=/app/backend \n\
env=DB_HOST="localhost",DB_PORT="5432",DB_USERNAME="kuser",DB_PASSWORD="kpass",DB_DATABASE="dashboard_db",PORT="3000" \n\
autorestart=true \n\
[program:nginx] \n\
command=nginx -g "daemon off;"' > /etc/supervisor/conf.d/supervisord.conf

# Portu ayarla ve başlat
EXPOSE 7860
CMD ["/usr/bin/supervisord"]