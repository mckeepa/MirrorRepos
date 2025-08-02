# Use a lightweight base image with httpd
FROM httpd:alpine

# Expose the directory /mnt/packages to the web server
RUN mkdir -p /data/packages
# RUN  chcon -R -t httpd_sys_content_t /mnt/packages
# RUN  chcon -R -t httpd_sys_content_t /data/packages

# # Configure httpd to serve files from /mnt/packages
# RUN sed -i 's|DocumentRoot "/usr/local/apache2/htdocs"|DocumentRoot "/data/packages"|' /usr/local/apache2/conf/httpd.conf && \
#     sed -i 's|<Directory "/usr/local/apache2/htdocs">|<Directory "/data/packages">|' /usr/local/apache2/conf/httpd.conf

#     # Enable mod_autoindex for directory listing
# RUN echo 'Options +Indexes' >> /usr/local/apache2/conf/httpd.conf && \
#     echo 'DirectoryIndex disabled' >> /usr/local/apache2/conf/httpd.conf
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf

# Enable mod_autoindex for directory listing
# RUN echo 'Options +Indexes' >> /usr/local/apache2/conf/httpd.conf

# Expose port 80 for the web server
EXPOSE 8080 8443


# Set the default command to start the httpd server
CMD ["httpd-foreground"]