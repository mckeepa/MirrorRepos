# Add the rule to the SELinux policy
sudo semanage fcontext -a -t httpd_sys_content_t "/data/repo/packages(/.*)?"

# Apply the new labels to the actual files
sudo restorecon -Rv /data/repo/packages

# sudo chmod 755 /data
# sudo chmod 755 /data/repo
# sudo chmod 755 /data/repo/packages

sudo find /data -type d -exec chmod 755 {} + && sudo find /data -type f -exec chmod 644 {} +

# check and fix ownership so the apache user can access the files:
sudo chown -R apache:apache /data && ls -ld /data /data/repo /data/repo/packages


 sudo vi /etc/httpd/conf.d/packages.conf 

 ```conf
Alias "/repos/packages" "/data/repo/packages"

<Directory "/data/repo/packages">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    
    # Optional: nicer visual layout
    IndexOptions FancyIndexing HTMLTable VersionSort NameWidth=*
</Directory>

 ```

33 Test and then restart

```bash 
sudo httpd -t
# If "Syntax OK", then:
sudo systemctl restart httpd
```

# TLS /SSL 

```bash
sudo dnf install mod_ssl
```

# Move certificates to a Secure Locations 
For security and SELinux compliance, it is best practice to store your keys in the standard system directories.

```bash
# Move the certificate
sudo mv cert.pem /etc/pki/tls/certs/cert.pem

# Move the private key
sudo mv key.pem /etc/pki/tls/private/key.pem

# /etc/pki/tls/certs/downloader.gardenofrot.cc.crt
# /etc/pki/tls/private/downloader.gardenofrot.cc.key

# Set secure permissions (root only for the key)
sudo chmod 600 /etc/pki/tls/private/key.pem
sudo chmod 644 /etc/pki/tls/certs/cert.pem
```

## Update the conf file

```bash
sudo vi /etc/httpd/conf.d/packages.conf
```

```conf
# Ensure Apache listens on the HTTPS port
Listen 443 https

<VirtualHost *:443>
    ServerName your-domain-or-ip
    DocumentRoot "/var/www/html"

    # Enable SSL
    SSLEngine on
    # SSLCertificateFile /etc/pki/tls/certs/cert.pem
    # SSLCertificateKeyFile /etc/pki/tls/private/key.pem
    SSLCertificateFile    /etc/pki/tls/certs/downloader.gardenofrot.cc.crt
    SSLCertificateKeyFile /etc/pki/tls/private/downloader.gardenofrot.cc.key

    # Your existing directory configuration
    Alias "/repos/packages" "/data/repo/packages"
    <Directory "/data/repo/packages">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
        IndexOptions FancyIndexing HTMLTable VersionSort NameWidth=*
    </Directory>

    ErrorLog logs/ssl_error_log
    TransferLog logs/ssl_access_log
</VirtualHost>

```

---------------------------------------------

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