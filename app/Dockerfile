# Use an official Nginx runtime as a parent image
FROM nginx:alpine

# Copy the local index.html file to the default Nginx public directory
COPY index.html /usr/share/nginx/html

# Expose port 80 to allow incoming HTTP traffic
EXPOSE 80

# Command to run Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"] 