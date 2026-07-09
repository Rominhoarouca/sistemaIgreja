FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html
COPY logo.png /usr/share/nginx/html/logo.png
COPY screens/ /usr/share/nginx/html/screens/

# Configuração nginx leve para SPA estática
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  index index.html;\n\
  location / {\n\
    try_files $uri $uri/ /index.html;\n\
  }\n\
  gzip on;\n\
  gzip_types text/html text/css application/javascript image/svg+xml;\n\
  add_header X-Frame-Options SAMEORIGIN;\n\
  add_header X-Content-Type-Options nosniff;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
