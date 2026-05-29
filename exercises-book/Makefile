MAIN = main
LATEX = xelatex
FLAGS = -interaction=nonstopmode -halt-on-error -shell-escape

.PHONY: all clean

all:
	$(LATEX) $(FLAGS) $(MAIN).tex
	$(LATEX) $(FLAGS) $(MAIN).tex

clean:
	rm -f *.aux *.log *.out *.toc *.idx *.ind *.ilg *.bbl *.blg *.synctex.gz
	find problems/ -name "*.aux" -delete 2>/dev/null || true
