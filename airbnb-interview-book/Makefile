# ============================================================================
# 《Airbnb 面试通关手册》 LaTeX 构建
# ============================================================================
#
# 用法：
#   make          # 两遍 xelatex，生成带目录/书签的 PDF
#   make once     # 只跑一遍（快速预览）
#   make tectonic # 用 tectonic 编译（无需本地 texlive）
#   make clean    # 清理构建产物
#
# 依赖（WSL/Linux）：
#   sudo apt install texlive-xetex texlive-lang-chinese texlive-latex-extra \
#        texlive-fonts-recommended
#   并安装 DejaVu Sans Mono 字体（fonts-dejavu）

MAIN = main
ENGINE = xelatex
FLAGS = -interaction=nonstopmode -halt-on-error -shell-escape

.PHONY: all once tectonic clean

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex preamble.tex chapters/*.tex
	$(ENGINE) $(FLAGS) $(MAIN).tex
	$(ENGINE) $(FLAGS) $(MAIN).tex

once:
	$(ENGINE) $(FLAGS) $(MAIN).tex

tectonic:
	tectonic -X compile $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.out *.idx *.ilg *.ind *.lof *.lot
	rm -f chapters/*.aux
	rm -f $(MAIN).pdf
