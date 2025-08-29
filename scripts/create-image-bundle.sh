#!/bin/bash

# Assign arguments
project_id="$1"
dockerfile="${2:-8.3.Dockerfile}"
repo_url="${3:-https://github.com/gogl92/docker-lemp}"
branch_name="${4:-deployer}"
root_branch_param="${5}"

# If the root branch is not provided as a parameter, detect the current branch of the root project
if [ -z "$root_branch_param" ]; then
  root_branch=$(git rev-parse --abbrev-ref HEAD)
else
  root_branch="$root_branch_param"
fi

# Create the project directory
mkdir -p "apps/$project_id/"

# Clone the specified branch of the specified repository
git clone --single-branch --branch "$branch_name" "$repo_url" "apps/$project_id"

# Backup and remove the existing PHP configuration
cp "apps/$project_id/php/php-fpm.ini" apps/php-fpm-tmp.ini
rm -rf "apps/$project_id/php"

# Sync the current directory to the PHP directory, excluding specific folders and files
rsync -av --exclude='apps' --exclude='.git' --exclude='vendor' ./ "apps/$project_id/php"

# Restore the PHP configuration
cp apps/php-fpm-tmp.ini "apps/$project_id/php/php-fpm.ini"

# Set permissions for necessary directories
mkdir -p "apps/$project_id/php/vendor"
chmod -R 777 "apps/$project_id/php/vendor" "apps/$project_id/php/storage" "apps/$project_id/php/bootstrap"

# Install Composer dependencies using laravelsail/php83-composer
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd)/apps/$project_id/php":/var/www/html \
    -w /var/www/html \
    laravelsail/php83-composer:latest \
    composer install --ignore-platform-reqs

# Set up the environment file
cp "apps/$project_id/php/.env.staging" "apps/$project_id/php/.env"

# Generate a new Laravel application key
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd)/apps/$project_id/php":/var/www/html \
    -w /var/www/html \
    laravelsail/php83-composer:latest \
    php /var/www/html/artisan key:generate

# Build the Docker image using the specified Dockerfile and tag it with the root project branch name
docker build -t "$project_id:$root_branch" -f "apps/$project_id/$dockerfile" "apps/$project_id"
