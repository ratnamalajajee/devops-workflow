# Static site served by nginx. Build & run:
#   docker build -t devops-launchpad .
#   docker run -d -p 8080:80 devops-launchpad
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/
COPY assets/ /usr/share/nginx/html/assets/
COPY content/ /usr/share/nginx/html/content/

EXPOSE 80
