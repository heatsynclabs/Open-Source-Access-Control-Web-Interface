# One-shot job for docker-compose.staging.yml: loads the newest nightly backup
# of the production members database into the staging database, then exits.
FROM postgres:16-alpine
COPY restore.sh /restore.sh
ENTRYPOINT ["sh", "/restore.sh"]
