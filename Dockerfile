FROM debezium/example-postgres:1.9 

# Copy in the load-extensions script
# COPY load-extensions.sh /docker-entrypoint-initdb.d/
# RUN chmod 755 /docker-entrypoint-initdb.d/load-extensions.sh

# Copy SQL files
COPY startup.sql /docker-entrypoint-initdb.d/
RUN chmod 755 /docker-entrypoint-initdb.d/startup.sql