"""Regenerate committed Office fixtures with python-docx, openpyxl, python-pptx.

These libraries are for fixture maintenance only, never runtime dependencies.
"""
from pathlib import Path
from docx import Document
from openpyxl import Workbook
from pptx import Presentation
from pptx.util import Inches

folder = Path(__file__).resolve().parent
doc = Document()
doc.add_heading("QuickConvert DOCX fixture", 0)
doc.add_paragraph("Local conversion test. 中文文件。")
table = doc.add_table(rows=2, cols=2)
table.cell(0, 0).text = "Format"
table.cell(0, 1).text = "PDF"
table.cell(1, 0).text = "Offline"
table.cell(1, 1).text = "Yes"
doc.add_page_break()
doc.add_paragraph("QuickConvert second page")
doc.save(folder / "document.docx")

book = Workbook()
for index in range(2):
    sheet = book.active if index == 0 else book.create_sheet()
    sheet.title = f"Sheet {index + 1}"
    sheet.append([f"QuickConvert sheet {index + 1}", "Amount"])
    sheet.append(["Offline", 42])
    sheet.column_dimensions["A"].width = 36
book.save(folder / "workbook.xlsx")

deck = Presentation()
for index in range(2):
    slide = deck.slides.add_slide(deck.slide_layouts[6])
    box = slide.shapes.add_textbox(Inches(1), Inches(1), Inches(8), Inches(2))
    box.text_frame.text = f"QuickConvert slide {index + 1}"
deck.save(folder / "presentation.pptx")
(folder / "page.html").write_text("<!doctype html><html><head><meta charset='utf-8'></head><body><h1>QuickConvert HTML fixture</h1><p>Local offline content.</p></body></html>")
