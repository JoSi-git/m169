#!/bin/bash
source .env
# create volume folders
mkdir ./scripts/Docker/moodle
mkdir ./scripts/Docker/moodledata
mkdir ./scripts/Docker/db_data


git clone -b MOODLE_403_STABLE https://github.com/moodle/moodle.git ./moodle

cd ./Docker
docker compose up -d

# mysql dump
mysqldump -u root -p"mysql-root-password" moodle > moodle.sql


# test
docker cp moodle.sql moodle-db:/moodle.sql

docker exec -it moodle-db bash
mysql -u root -p moodle < /moodle.sql


