FROM nginx:alpine
COPY ./index.html /usr/share/nginx/html/index.html
COPY ./n8n-workflows.html /usr/share/nginx/html/n8n-workflows.html

# Custom nginx config to listen on 3000
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000