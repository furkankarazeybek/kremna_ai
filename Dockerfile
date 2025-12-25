# 1. Aşama: Build
FROM node:20-slim AS builder
WORKDIR /app/backend
COPY dashboard_backend/package*.json ./
RUN npm install
COPY dashboard_backend/ .
RUN npm run build

WORKDIR /app/frontend
COPY dashboard_frontend/package*.json ./
RUN npm install
COPY dashboard_frontend/ .
ENV REACT_APP_API_URL=/api/v1
RUN npm run build

WORKDIR /app/widget
COPY chatbot_widget/package*.json ./
RUN npm install
COPY chatbot_widget/ .
RUN npm run build

# 2. Aşama: Runtime
FROM node:20-slim

# Paketler (Postgres 15 ve Nginx)
RUN apt-get update && \
    apt-get install -y postgresql-15 postgresql-contrib-15 nginx supervisor netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/node_modules ./backend/node_modules
COPY --from=builder /app/backend/package.json ./backend/package.json
COPY --from=builder /app/frontend/build /usr/share/nginx/html/dashboard
COPY --from=builder /app/widget/dist /usr/share/nginx/html/widget

# ÖNEMLİ: Hugging Face izinleri için klasörleri önceden hazırla
RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql
RUN mkdir -p /var/lib/postgresql/15/main && chown -R postgres:postgres /var/lib/postgresql/15/main
RUN mkdir -p /var/log/supervisor && chmod 777 /var/log/supervisor

# DB Kurulumu
USER postgres
RUN /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main || echo "Already Init"
RUN /usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main start && \
    psql --command "CREATE USER kuser WITH SUPERUSER PASSWORD 'kpass';" && \
    createdb -O kuser dashboard_db && \
    /usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main stop

USER root
# Nginx Ayarı (Hatasız tek satır)
RUN echo 'server { listen 7860; location / { root /usr/share/nginx/html/dashboard; try_files $uri $uri/ /index.html; } location /widget { alias /usr/share/nginx/html/widget; try_files $uri $uri/ /index.html; } location /api/v1 { proxy_pass http://127.0.0.1:3000; proxy_set_header Host $host; } location /socket.io { proxy_pass http://127.0.0.1:3000; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "Upgrade"; } }' > /etc/nginx/sites-available/default

# Supervisor Ayarı (Garantili Başlatma ve Detaylı Log)
RUN printf '[supervisord]\nnodaemon=true\nuser=root\n\n[program:postgres]\ncommand=/usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main\nuser=postgres\nautorestart=true\n\n[program:backend]\ncommand=/bin/bash -c "sleep 5; until nc -z 127.0.0.1 5432; do echo Waiting DB...; sleep 2; done; node /app/backend/dist/main.js"\ndirectory=/app/backend\nenv=DB_HOST="127.0.0.1",DB_PORT="5432",DB_USERNAME="kuser",DB_PASSWORD="kpass",DB_DATABASE="dashboard_db",PORT="3000"\nautorestart=true\nstdout_logfile=/dev/stdout\nstderr_logfile=/dev/stderr\n\n[program:nginx]\ncommand=nginx -g "daemon off;"\nautorestart=true\n' > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 7860
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]