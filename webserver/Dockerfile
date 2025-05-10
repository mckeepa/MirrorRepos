# Use a lightweight base image with httpd
FROM httpd:alpine

# Expose the directory /mnt/packages to the web server
RUN mkdir -p /mnt/packages

# Configure httpd to serve files from /mnt/packages
RUN sed -i 's|DocumentRoot "/usr/local/apache2/htdocs"|DocumentRoot "/mnt/packages"|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|<Directory "/usr/local/apache2/htdocs">|<Directory "/mnt/packages">|' /usr/local/apache2/conf/httpd.conf

# Expose port 80 for the web server
EXPOSE 80

# Set the default command to start the httpd server
CMD ["httpd-foreground"]