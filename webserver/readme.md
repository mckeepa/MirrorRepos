# Start the Web Server
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem -subj "/CN=localhost"
````



```bash
# podman run -dt -v "$(pwd)":/data/packages/:Z -v "$(pwd)"/httpd.conf:/usr/local/apache2/conf/httpd.conf:Z -v "$(pwd)"/httpscert/:/httpscert/  -p 8080:80/tcp -p 8443:443/tcp --name repo-web  docker.io/library/httpd 


# podman run -dt --replace -v /data/repo-mirror/:/data/packages/:Z -v /data/config/httpd.conf:/usr/local/apache2/conf/httpd.conf:Z -v /data/config/httpscert/:/httpscert/  -p 8080:80/tcp -p 8443:443/tcp --name repo-web  docker.io/library/httpd 

# podman run -dt --replace -v /data/repo-mirror/:/data/packages/ -v /data/config/httpd.conf:/usr/local/apache2/conf/httpd.conf -v /data/config/httpscert/:/httpscert/  -p 8080:80/tcp -p 8443:443/tcp --name repo-web  docker.io/library/httpd

#  podman run -it --replace -v /data/repo-mirror/:/data/packages/ -v /data/config/httpd.conf:/usr/local/apache2/conf/httpd.conf:z -v /data/config/httpscert/:/httpscert/:z  -p 8080:80/tcp -p 8443:443/tcp --name repo-web  docker.io/library/httpd 

podman run -it --replace -v /data/repo-mirror/:/data/packages/:Z -v /data/config/httpd.conf:/usr/local/apache2/conf/httpd.conf:Z -v /data/config/httpscert/:/httpscert/  -p 8080:80/tcp -p 8443:443/tcp --name repo-web  docker.io/library/httpd


```