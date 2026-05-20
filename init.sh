#!/bin/bash
# Runs inside the MySQL container on first start via /docker-entrypoint-initdb.d/
# Restricts lime_user to only the privileges LimeSurvey needs.
# The MySQL image grants ALL PRIVILEGES by default; this tightens that down.
set -e

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<SQL
REVOKE ALL PRIVILEGES, GRANT OPTION ON \`${MYSQL_DATABASE}\`.* FROM '${MYSQL_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
    ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL
