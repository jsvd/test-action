FROM logstash:7.14.0

LABEL "com.github.actions.name"="Verify version bump in Logstash Plugin PR"
LABEL "com.github.actions.description"="Example code for building a GitHub Action with the language you love, Ruby."
LABEL "com.github.actions.icon"="filter"
LABEL "com.github.actions.color"="red"

COPY entrypoint.sh /entrypoint.sh
COPY action.rb /action.rb

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
