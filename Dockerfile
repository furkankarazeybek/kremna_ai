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

# Gerekli paketleri kur (Postgres 15, nginx, supervisor, netcat)
RUN apt-get update && \
    apt-get install -y postgresql-15 postgresql-contrib-15 nginx supervisor netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# Uygulama dosyalarını kopyala
WORKDIR /app
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/node_modules ./backend/node_modules
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/frontend/build /usr/share/nginx/html/dashboard
COPY --from=builder /app/widget/dist /usr/share/nginx/html/widget

# Postgres Başlangıç Verilerini Oluştur
USER postgres
RUN /etc/init.d/postgresql start && \
    psql --command "CREATE USER kuser WITH SUPERUSER PASSWORD 'kpass';" && \
    createdb -O kuser dashboard_db
USER root

# Postgres Socket Klasörünü Hazırla
RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

# Nginx Yapılandırması (HATALI SATIR DÜZELTİLDİ)
# proxy_set_header Connection "Upgrade"; satırı tek parça olmalı.
RUN printf 'server {\n\
    listen 7860;\n\
    location / {\n\
        root /usr/share/nginx/html/dashboard;\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    location /widget {\n\
        alias /usr/share/nginx/html/widget;\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    location /api/v1 {\n\
        proxy_pass http://127.0.0.1:3000;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Upgrade $http_upgrade;\n\
        proxy_set_header Connection "Upgrade";\n\
        proxy_set_header Host $host;\n\
    }\n\
    location /socket.io {\n\
        proxy_pass http://127.0.0.1:3000;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Upgrade $http_upgrade;\n\
        proxy_set_header Connection "Upgrade";\n\
    }\n\
}' > /etc/nginx/sites-available/default

# Supervisord Yapılandırması
RUN printf '[supervisord]\n\
nodaemon=true\n\
logfile=/dev/null\n\
logfile_maxbytes=0\n\
\n\
[program:postgres]\n\
command=/bin/bash -c "rm -f /var/lib/postgresql/15/main/postmaster.pid && /usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main -c config_file=/etc/postgresql/15/main/postgresql.conf"\n\
user=postgres\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:backend]\n\
command=/bin/bash -c "echo Waiting for DB on 5432...; until nc -z 127.0.0.1 5432; do echo ...DB not ready yet; sleep 1; done; echo DB Ready! Starting NestJS...; node /app/backend/dist/main.js"\n\
directory=/app/backend\n\
env=DB_HOST="127.0.0.1",DB_PORT="5432",DB_USERNAME="kuser",DB_PASSWORD="kpass",DB_DATABASE="dashboard_db",PORT="3000"\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:nginx]\n\
command=nginx -g "daemon off;"\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n' > /etc/supervisor/conf.d/supervisord.conf

# Portu ayarla ve başlat
EXPOSE 7860
CMD ["/usr/bin/supervisord"]