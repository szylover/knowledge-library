# ============================================================================
# 《多邻国 Android 面试通关手册》 LaTeX 构建
# ============================================================================
#
# 用法：
#   make          # 两遍 xelatex，生成带目录/书签的 PDF
#   make drills   # 生成遮蔽版习题册 drills.pdf（只有题面，无答案）
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

.PHONY: all once tectonic drills clean

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex preamble.tex chapters/*.tex
	$(ENGINE) $(FLAGS) $(MAIN).tex
	$(ENGINE) $(FLAGS) $(MAIN).tex

# 遮蔽版习题册：从正文抽出题面，剥掉全部答案。
# drills.tex 是生成物，不要手改——改了会被下一次 make drills 覆盖。
drills: drills.pdf

drills.pdf: make-drills.mjs preamble.tex chapters/*.tex
	node make-drills.mjs
	$(ENGINE) $(FLAGS) drills.tex
	$(ENGINE) $(FLAGS) drills.tex

once:
	$(ENGINE) $(FLAGS) $(MAIN).tex

tectonic:
	tectonic -X compile $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.out *.idx *.ilg *.ind *.lof *.lot
	rm -f chapters/*.aux
	rm -f $(MAIN).pdf drills.pdf drills.tex
