.PHONY: compile
compile:
	mkdir -p ./tmp
	for f in *.mmd; do NAME=$${f:0:-4}; ./mmdc -i $$f -o $$NAME.svg; convert $$NAME.svg ./tmp/$$NAME.pdf; done

.PHONY: watch
watch-%: compile
	okular ./tmp/$(*).pdf &
	find . | entr make compile
