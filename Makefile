TERRAFORM := terraform
TF_DIR := terrform

.PHONY: tf-init tf-apply tf-sync start stop restart status logs open-vnc open-web open-portal curl-health portal-health config backups

tf-init:
	@$(TERRAFORM) -chdir="$(TF_DIR)" init -input=false >/dev/null

tf-apply: tf-init
	@$(TERRAFORM) -chdir="$(TF_DIR)" apply -auto-approve -input=false >/dev/null

tf-sync: tf-apply

start: tf-apply
	@pidfile="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw pidfile_path)"; \
	logfile="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw logfile_path)"; \
	vm_name="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw vm_name)"; \
	requires_root="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw qemu_requires_root)"; \
	pid=""; \
	if [ -f "$$pidfile" ]; then pid="$$(cat "$$pidfile" 2>/dev/null || true)"; fi; \
	if [ -z "$$pid" ]; then pid="$$(pgrep -f "qemu-system.*-name $$vm_name" | head -1 || true)"; fi; \
	if [ -n "$$pid" ] && ps -p "$$pid" >/dev/null 2>&1; then \
		echo "$$vm_name is already running with pid $$pid"; \
	else \
		cmd="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw qemu_command_exec)"; \
		if [ "$$requires_root" = "true" ]; then \
			sudo sh -c "$$cmd"; \
		else \
			eval "$$cmd"; \
		fi; \
		if [ -f "$$pidfile" ] && kill -0 "$$(cat "$$pidfile")" 2>/dev/null; then \
			echo "started $$vm_name with pid $$(cat "$$pidfile")"; \
		else \
			echo "failed to start $$vm_name; see $$logfile" >&2; \
			exit 1; \
		fi; \
	fi

stop: tf-init
	@pidfile="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw pidfile_path)"; \
	vm_name="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw vm_name)"; \
	requires_root="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw qemu_requires_root)"; \
	pid=""; \
	if [ -f "$$pidfile" ]; then pid="$$(cat "$$pidfile" 2>/dev/null || true)"; fi; \
	if [ -z "$$pid" ]; then pid="$$(pgrep -f "qemu-system.*-name $$vm_name" | head -1 || true)"; fi; \
	if [ -n "$$pid" ] && ps -p "$$pid" >/dev/null 2>&1; then \
		if ! kill "$$pid" 2>/dev/null; then \
			if [ "$$requires_root" = "true" ]; then \
				sudo kill "$$pid"; \
			else \
				exit 1; \
			fi; \
		fi; \
		for _ in $$(seq 1 50); do \
			if ps -p "$$pid" >/dev/null 2>&1; then \
				sleep 0.1; \
			else \
				break; \
			fi; \
		done; \
		if ps -p "$$pid" >/dev/null 2>&1; then \
			echo "$$vm_name is still stopping with pid $$pid" >&2; \
			exit 1; \
		fi; \
		if ! rm -f "$$pidfile" 2>/dev/null; then \
			if [ "$$requires_root" = "true" ]; then \
				sudo rm -f "$$pidfile"; \
			else \
				exit 1; \
			fi; \
		fi; \
		echo "stopped $$vm_name"; \
	else \
		if ! rm -f "$$pidfile" 2>/dev/null; then \
			if [ "$$requires_root" = "true" ]; then \
				sudo rm -f "$$pidfile"; \
			else \
				exit 1; \
			fi; \
		fi; \
		echo "$$vm_name is already stopped"; \
	fi

restart: stop start

status: tf-init
	@pidfile="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw pidfile_path)"; \
	vm_name="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw vm_name)"; \
	pid=""; \
	if [ -f "$$pidfile" ]; then pid="$$(cat "$$pidfile" 2>/dev/null || true)"; fi; \
	if [ -z "$$pid" ]; then pid="$$(pgrep -f "qemu-system.*-name $$vm_name" | head -1 || true)"; fi; \
	if [ -n "$$pid" ] && ps -p "$$pid" >/dev/null 2>&1; then \
		ps -p "$$pid" -o pid=,etime=,comm=; \
	else \
		echo "$$vm_name is not running"; \
	fi

logs: tf-init
	@logfile="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw logfile_path)"; \
	requires_root="$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw qemu_requires_root)"; \
	if [ "$$requires_root" = "true" ]; then \
		sudo tail -f "$$logfile"; \
	else \
		tail -f "$$logfile"; \
	fi

open-vnc: tf-init
	@open "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw vnc_url)"

open-web: tf-init
	@open "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw web_ui_url)"

open-portal: tf-init
	@open "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw portal_http_url)"

curl-health: tf-init
	@curl -skI --connect-timeout 5 --max-time 12 "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw web_ui_url)"

portal-health: tf-init
	@curl -sI --connect-timeout 5 --max-time 12 "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw portal_http_url)"

config: tf-init
	@KEY="$$(grep '^key=' "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw apikey_path)" | cut -d= -f2-)"; \
	SECRET="$$(grep '^secret=' "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw apikey_path)" | cut -d= -f2-)"; \
	curl -sk -u "$$KEY:$$SECRET" \
		"$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw api_base_url)/api/core/backup/download/this"

backups: tf-init
	@KEY="$$(grep '^key=' "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw apikey_path)" | cut -d= -f2-)"; \
	SECRET="$$(grep '^secret=' "$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw apikey_path)" | cut -d= -f2-)"; \
	curl -sk -u "$$KEY:$$SECRET" \
		"$$($(TERRAFORM) -chdir="$(TF_DIR)" output -raw api_base_url)/api/core/backup/backups/this"
