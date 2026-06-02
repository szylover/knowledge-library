MAIN = main
ENGINE = xelatex
FLAGS = -interaction=nonstopmode -halt-on-error -shell-escape

.PHONY: all once clean

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex preamble.tex chapters/*.tex
	$(ENGINE) $(FLAGS) $(MAIN).tex
	$(ENGINE) $(FLAGS) $(MAIN).tex

once:
	$(ENGINE) $(FLAGS) $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.out *.idx *.ilg *.ind *.listing
	rm -f chapters/*.aux
	rm -f $(MAIN).pdf
