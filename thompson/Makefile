SHELL := /bin/bash

all: thompson

thompson:
	flex thompson.l
	bison thompson.y
	gcc -o thompson thompson.tab.c

run:
	./thompson

pdf:
	dot -Tpdf thompson.gv  -o thompson.pdf
	open thompson.pdf

clean:
	rm -f thompson.output thompson.tab.c lex.yy.c thompson
