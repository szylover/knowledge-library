# ============================================================================
# 《模形式的代数基础》 LaTeX 构建
# ============================================================================
#
# 用法：
#   make          # 编译 PDF（两遍 xelatex 生成目录）
#   make once     # 只跑一遍（快速预览）
#   make clean    # 清理构建产物
#
# 依赖：
#   sudo apt install texlive-xetex texlive-lang-chinese texlive-latex-extra \
#        texlive-fonts-recommended texlive-science

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
