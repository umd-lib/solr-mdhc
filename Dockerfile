# Cleanup data.csv
FROM python:3.8 as cleaner

# Add the files
COPY data.csv /tmp/data.csv
COPY scripts/cleanup.py /tmp/cleanup.py

# Run the data cleanup
RUN python /tmp/cleanup.py --infile=/tmp/data.csv --outfile=/tmp/clean.csv

# Validate data.csv using csv-validator 1.1.5
# https://digital-preservation.github.io/csv-validator/

FROM docker.lib.umd.edu/csv-validator:1.1.5-umd-0 as validator

COPY --from=cleaner /tmp/clean.csv /tmp/clean.csv
COPY data.csvs /tmp/data.csvs

RUN validate /tmp/clean.csv /tmp/data.csvs

# Load data.csv into the Solr core
FROM solr:8 as builder

# Switch to root user
USER root

# Install xmlstarlet
RUN apt-get update -y && \
    apt-get install -y xmlstarlet

# Set the SOLR_HOME directory env variable
ENV SOLR_HOME=/apps/solr/data

RUN mkdir -p /apps/solr/ && \
    cp -r /opt/solr/server/solr /apps/solr/data && \
    wget --directory-prefix=/apps/solr/data/lib "https://maven.lib.umd.edu/nexus/repository/releases/edu/umd/lib/umd-solr/2.2.2-2.4/umd-solr-2.2.2-2.4.jar" && \
    wget --directory-prefix=/apps/solr/data/lib "https://maven.lib.umd.edu/nexus/repository/central/joda-time/joda-time/2.2/joda-time-2.2.jar" && \
    chown -R solr:0 "$SOLR_HOME"

# Switch back to solr user
USER solr

# Create the "mdhc" core
RUN /opt/solr/bin/solr start && \
    /opt/solr/bin/solr create_core -c mdhc && \
    /opt/solr/bin/solr stop

# Replace the schema file
COPY conf /apps/solr/data/mdhc/conf/

# Add the data to be loaded
COPY --from=cleaner /tmp/clean.csv /tmp/clean.csv

# Load the data to mdhc core
RUN /opt/solr/bin/solr start && sleep 3 && \
    curl 'http://localhost:8983/solr/mdhc/update?commit=true' -H 'Content-Type: text/xml' --data-binary '<delete><query>*:*</query></delete>' && \
    curl -v "http://localhost:8983/solr/mdhc/update/csv?commit=true&f.categories.split=true&f.categories.separator=;&f.categories.trim=true" \
    --data-binary @/tmp/clean.csv -H 'Content-type:text/csv; charset=utf-8' && \
    /opt/solr/bin/solr stop

# Create the Solr runtime container
FROM solr:8-slim

ENV SOLR_HOME=/apps/solr/data

USER root
RUN mkdir -p /apps/solr/

USER solr
COPY --from=builder /apps/solr/ /apps/solr/
