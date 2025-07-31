#!/bin/bash

# Update and install required packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-venv nginx git

# Navigate to home directory or project directory
cd ~

# Clone your Django project repo if not already present (replace with your repo URL)
# git clone https://github.com/yourusername/yourproject.git
# cd yourproject

# Assuming project is already present in current directory
PROJECT_DIR=$(pwd)

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

# Collect static files
python manage.py collectstatic --noinput

# Install Gunicorn
pip install gunicorn

# Create systemd service file for Gunicorn
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=gunicorn daemon for Django project
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory='$PROJECT_DIR'
ExecStart='$PROJECT_DIR'/venv/bin/gunicorn --access-logfile - --workers 3 --bind unix:'$PROJECT_DIR'/gunicorn.sock mysite.wsgi:application

[Install]
WantedBy=multi-user.target
EOF'

# Start and enable Gunicorn service
sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

# Configure Nginx
sudo bash -c 'cat > /etc/nginx/sites-available/django_project << EOF
server {
    listen 80;
    server_name steelakhavan.com www.steelakhavan.com;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root '$PROJECT_DIR';
    }

    location /media/ {
        root '$PROJECT_DIR';
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:'$PROJECT_DIR'/gunicorn.sock;
    }
}
EOF'

# Enable Nginx site and restart service
sudo ln -sf /etc/nginx/sites-available/django_project /etc/nginx/sites-enabled
sudo nginx -t
sudo systemctl restart nginx

echo "Deployment script completed. Please ensure DNS for steelakhavan.com points to this server's IP."
