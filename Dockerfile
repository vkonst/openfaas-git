# Run tgsend (send to Telegram) utility as OpenFaas function 
# To build:
# docker build -t tgsend .

FROM openfaas/classic-watchdog:0.13.4 as watchdog

FROM alpine:3.9
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog

RUN apk add bash curl --no-cache && \
	chmod +x /usr/bin/fwatchdog && \
	mkdir -p /home/app && \
	addgroup -S app && \
	adduser app -S -G app && \
	chown app /home/app

WORKDIR /home/app

COPY ./ /home/app/
RUN chmod +x /home/app/tgsend.sh

USER app

ENV fprocess="/home/app/tgsend.sh"
# Set to true to see request in function logs
ENV write_debug="false"

EXPOSE 8080

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

ENTRYPOINT ["fwatchdog"]
