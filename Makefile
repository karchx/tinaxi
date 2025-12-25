.PHONY: run

run:
	exec 3<>/dev/tcp/127.0.0.1/9999

.PHONY: send

send:
	@echo 'P' >&3

.PHONY: receive
	read response <&3

.PHONY: show
	@echo $response

