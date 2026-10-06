ARG GUACAMOLE_VERSION
FROM guacamole/guacamole:${GUACAMOLE_VERSION}

USER root

COPY custom-ca-certificate.crt /tmp/custom-ca-certificate.crt

RUN keytool \
    -importcert \
    -cacerts \
    -storepass changeit \
    -noprompt \
    -alias company-root-ca \
    -file /tmp/custom-ca-certificate.crt \
 && rm /tmp/custom-ca-certificate.crt

USER guacamole
