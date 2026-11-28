import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

doc = docx.Document()

# Page Margins (Normal: 1 inch around)
sections = doc.sections
for section in sections:
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

# Helper function to set Thai font (TH Sarabun PSK or TH Sarabun New)
def set_run_font(run, font_name="TH Sarabun PSK", size_pt=16, bold=False, italic=False, color_rgb=(0, 0, 0)):
    run.font.name = font_name
    run.font.size = Pt(size_pt)
    run.bold = bold
    run.italic = italic
    run.font.color.rgb = RGBColor(*color_rgb)
    # Set complex script font for Thai rendering in Word / Google Docs
    rPr = run._r.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:cs'), font_name)
    rFonts.set(qn('w:eastAsia'), font_name)
    rFonts.set(qn('w:hAnsi'), font_name)
    rFonts.set(qn('w:ascii'), font_name)

def add_custom_heading(doc, text, level=1):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.15
    run = p.add_run(text)
    if level == 1:
        set_run_font(run, font_name="TH Sarabun PSK", size_pt=20, bold=True, color_rgb=(24, 76, 120))
    elif level == 2:
        set_run_font(run, font_name="TH Sarabun PSK", size_pt=18, bold=True, color_rgb=(33, 33, 33))
    elif level == 3:
        set_run_font(run, font_name="TH Sarabun PSK", size_pt=16, bold=True, color_rgb=(50, 50, 50))
    return p

def add_body_paragraph(doc, text="", space_after=6, bold=False):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.15
    if text:
        run = p.add_run(text)
        set_run_font(run, font_name="TH Sarabun PSK", size_pt=16, bold=bold)
    return p

def add_placeholder_box(doc, title, subtitle):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    cell = table.cell(0, 0)
    cell.width = Inches(6.5)
    
    # Border & shading
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>\n'
        f'  <w:top w:val="dashed" w:sz="12" w:space="0" w:color="9E9E9E"/>\n'
        f'  <w:left w:val="dashed" w:sz="12" w:space="0" w:color="9E9E9E"/>\n'
        f'  <w:bottom w:val="dashed" w:sz="12" w:space="0" w:color="9E9E9E"/>\n'
        f'  <w:right w:val="dashed" w:sz="12" w:space="0" w:color="9E9E9E"/>\n'
        f'</w:tcBorders>'
    )
    tcPr.append(tcBorders)
    
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="F5F7FA"/>')
    tcPr.append(shading)
    
    # Text inside placeholder
    p = cell.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(20)
    p.paragraph_format.space_after = Pt(4)
    run1 = p.add_run(f"📷 [พื้นที่สำหรับวางภาพ: {title}]\n")
    set_run_font(run1, font_name="TH Sarabun PSK", size_pt=15, bold=True, color_rgb=(100, 116, 139))
    
    p2 = cell.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p2.paragraph_format.space_before = Pt(0)
    p2.paragraph_format.space_after = Pt(20)
    run2 = p2.add_run(f"({subtitle})")
    set_run_font(run2, font_name="TH Sarabun PSK", size_pt=13, italic=True, color_rgb=(148, 163, 184))
    
    # spacing after table
    post_p = doc.add_paragraph()
    post_p.paragraph_format.space_before = Pt(0)
    post_p.paragraph_format.space_after = Pt(6)

# --- START DOCUMENT CONTENT ---

# Main Title (ส่วนที่ 1 & 2 Header)
p_title = doc.add_paragraph()
p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
p_title.paragraph_format.space_after = Pt(12)
r_title = p_title.add_run("เอกสารรวบรวมและนำเสนอผลงาน\nรายวิชา การจัดการระบบสารสนเทศดิจิทัล ภาคเรียนที่ 1/2569")
set_run_font(r_title, font_name="TH Sarabun PSK", size_pt=22, bold=True, color_rgb=(20, 50, 90))

# ส่วนที่ 1: ข้อมูลผู้จัดทำ
add_custom_heading(doc, "ส่วนที่ 1 ข้อมูลผู้จัดทำ", level=1)
p_sec1 = add_body_paragraph(doc, "ชื่อ-นามสกุล นักศึกษา: ..................................................................................... รหัสนักศึกษา: .....................................")
p_sec1_2 = add_body_paragraph(doc, "กลุ่มเรียน (Sect): ............ อาจารย์ผู้สอน: ผศ.สัณชัย ยงกุลวณิช")
p_sec1_3 = add_body_paragraph(doc, "สถานะ: ผู้ฝึกปฏิบัติและจัดทำผลงานจนแล้วเสร็จ และได้ทำการทดลองปรับใช้งานแล้ว")

# เส้นคั่น
doc.add_paragraph().paragraph_format.space_after = Pt(8)

# ส่วนที่ 2
add_custom_heading(doc, "ส่วนที่ 2 การแสดงเพื่อนำเสนอผลงานแอปพลิเคชันตามลำดับ", level=1)

# เรื่องที่ 6: แอปพลิเคชันหมูกระทะทวิทรัพย์กอง
add_custom_heading(doc, "ผลงานที่ 6: แอปพลิเคชันบันทึกข้อมูลคำสั่งซื้อร้านหมูกระทะทวิทรัพย์กอง (ข้อสอบปฏิบัติ)", level=2)

# คำอธิบายภาพรวม
p_overview = add_body_paragraph(doc)
r_ov1 = p_overview.add_run("แอปพลิเคชันนี้พัฒนาขึ้นด้วยแพลตฟอร์ม AppSheet เพื่อรองรับการบันทึกคำสั่งซื้อและการจัดส่งของร้านหมูกระทะทวิทรัพย์กอง โดยเชื่อมโยงฐานข้อมูลร่วมกับ Google Sheets เพื่อเปลี่ยนกระบวนการรับคำสั่งซื้อทางโทรศัพท์แบบเดิมให้เป็นระบบดิจิทัลที่คำนวณราคาอัตโนมัติ สร้าง QR Code ชำระเงิน และเก็บข้อมูลแบบเรียลไทม์")
set_run_font(r_ov1, font_name="TH Sarabun PSK", size_pt=16)

# 1. การรับเข้าข้อมูล (Input & UI)
add_custom_heading(doc, "1. การรับเข้าข้อมูล (Input) และส่วนติดต่อผู้ใช้งาน (UI)", level=3)
p_input = add_body_paragraph(doc)
r_in = p_input.add_run("ระบบทำหน้าที่รับข้อมูลผ่านหน้าจอแบบฟอร์ม (Form View) ซึ่งถูกออกแบบตามเงื่อนไขทางธุรกิจ ดังนี้:\n"
                       "• ข้อมูลผู้สั่งและการจัดส่ง: บันทึกชื่อ-นามสกุล, เบอร์โทรศัพท์ของผู้รับ, รายละเอียดสถานที่จัดส่ง (บ้านเลขที่, ซอย, ถนน, จุดสังเกต) และพิกัดระบุตำแหน่งบนแผนที่ผ่าน Google Maps (Type: LatLong / Address)\n"
                       "• วันที่และรอบเวลาจัดส่ง: กำหนดให้วันที่ส่งเป็นวันปัจจุบันโดยอัตโนมัติ (Default: TODAY()) และเลือกรอบเวลาส่งได้ 1 รอบเท่านั้น (รอบ 18.00 น., 19.00 น. หรือ 20.00 น.) โดยมีเงื่อนไขตรวจสอบให้ระบุเฉพาะรอบเวลาในอนาคต\n"
                       "• รายการชุดหมูกระทะ: กำหนดให้เลือกสั่งได้ครั้งละ 1 รายการ ประกอบด้วย setA ชุดเล็ก (199 บาท), setB ชุดกลาง (299 บาท), setC ชุดใหญ่ใจใหญ่ (399 บาท) หรือ setD ชุดซีฟู้ดจัดเต็ม (359 บาท)\n"
                       "• ตัวเลือกเพิ่มเติม: ลูกค้าสามารถเลือกชนิดน้ำซุป (ซุปใสออริจินัล, ซุปหม่าล่า, ซุปต้มยำ) และชนิดน้ำจิ้ม (น้ำจิ้มหมูกระทะ, น้ำจิ้มซีฟู้ด, น้ำจิ้มแจ่ว) ได้มากกว่า 1 รายการ (Type: EnumList)")
set_run_font(r_in, font_name="TH Sarabun PSK", size_pt=16)

add_placeholder_box(doc, "ภาพหน้าจอแบบฟอร์มรับคำสั่งซื้อ (Form View UI)", "แคปเจอร์หน้าจอ UI ขณะกรอกข้อมูล ชื่อ-เบอร์โทร, ที่อยู่จัดส่ง, การเลือกชุด, น้ำซุป และน้ำจิ้ม")

# 2. การเชื่อมโยงและการประมวลผลข้อมูล (Data Relationship & Payment Processing)
add_custom_heading(doc, "2. การเชื่อมโยงข้อมูล การคำนวณราคา และระบบชำระเงิน (Data Processing & Payment)", level=3)
p_proc = add_body_paragraph(doc)
r_pr = p_proc.add_run("ระบบมีกลไกการเชื่อมโยงตารางข้อมูลและประมวลผลคำนวณยอดเงินอัตโนมัติ ดังนี้:\n"
                      "• การดึงข้อมูลรายการและราคา: ระบบเชื่อมโยงข้อมูลกับตารางรายการอาหารเพื่อดึง 'ชื่อชุด' และ 'ราคาบาท' มาประมวลผลคำนวณเป็น 'ราคาจ่าย' (ยอดรวมสุทธิ) โดยอัตโนมัติ\n"
                      "• การสร้าง QR Code ชำระเงินอัตโนมัติ: เมื่อมีราคาจ่ายเข้ามา ระบบจะสร้าง QR Code พร้อมเพย์ประเภท Image ทันทีผ่านลิงก์ https://promptpay.io/เบอร์โทรPromptPay/[ราคาจ่าย]\n"
                      "• เงื่อนไขปุ่มยืนยันชำระเงิน: กำหนดเงื่อนไขให้แสดงปุ่ม 'ยืนยันชำระเงินแล้ว' จำนวน 1 ปุ่มเมื่อมียอดราคาจ่ายเข้ามา โดยผู้ใช้ยังสามารถแก้ไขได้หากสถานะยืนยันยังเป็นค่าว่าง\n"
                      "• ส่วนแนบหลักฐานการโอน: เมื่อผู้ใช้กดปุ่มยืนยันแล้ว ระบบจะเปิดการแสดงผลส่วนแนบภาพหน้าจอโอนจ่าย (Type: Image) เพื่อให้อัปโหลดสลิปยืนยัน")
set_run_font(r_pr, font_name="TH Sarabun PSK", size_pt=16)

add_placeholder_box(doc, "ภาพหน้าจอการแสดงผล QR Code ชำระเงิน และปุ่มยืนยันพร้อมแนบสลิป", "แคปเจอร์หน้าจอแสดง QR Code PromptPay, ปุ่มกดยืนยันชำระเงิน และช่องแนบภาพสลิปโอนเงิน")

# 3. โครงสร้างฐานข้อมูลและการจัดเก็บบน Google Sheets
add_custom_heading(doc, "3. โครงสร้างฐานข้อมูลและการจัดเก็บลง Google Sheets (Data Storage)", level=3)
p_db = add_body_paragraph(doc)
r_db = p_db.add_run("ข้อมูลรายการคำสั่งซื้อ รายละเอียดการจัดส่ง และสถานะการชำระเงินทั้งหมด จะถูกจัดส่งไปบันทึกลงในฐานข้อมูล Google Sheets ของทางร้านโดยอัตโนมัติ เพื่อให้ผู้ดูแลระบบสามารถตรวจสอบและดำเนินการจัดส่งได้อย่างถูกต้องแม่นยำ")
set_run_font(r_db, font_name="TH Sarabun PSK", size_pt=16)

add_placeholder_box(doc, "ภาพโครงสร้างตารางข้อมูลใน Google Sheets", "แคปเจอร์หน้า Google Sheets แสดงหัวตาราง คอลัมน์ข้อมูล และแถวข้อมูลที่มีการบันทึกคำสั่งซื้อเข้ามาจริง")

# 4. ลิงก์การเข้าถึงแอปพลิเคชันและการทดสอบ
add_custom_heading(doc, "4. ลิงก์การแชร์แอปพลิเคชันและการทดสอบบนเบราว์เซอร์ (App Deployment & Testing)", level=3)
p_link = add_body_paragraph(doc)
r_lk1 = p_link.add_run("ลิงก์แอปพลิเคชัน (AppSheet Shared Link):\n")
set_run_font(r_lk1, font_name="TH Sarabun PSK", size_pt=16, bold=True)
r_lk2 = p_link.add_run("https://www.appsheet.com/start/d760a46b-5d9b-4319-8d2a-e7455ded7fff\n\n")
set_run_font(r_lk2, font_name="TH Sarabun PSK", size_pt=15, color_rgb=(26, 115, 232))
r_lk3 = p_link.add_run("การตั้งค่าการเข้าถึง: ได้ทำการตั้งค่าอนุญาตให้เข้าใช้งานแอปพลิเคชันได้โดยไม่ต้องลงชื่อเข้าใช้ (No Sign-in required) ตามคำแนะนำในชั้นเรียน พร้อมทั้งทดสอบคัดลอกลิงก์ไปเปิดรันบนเว็บเบราว์เซอร์ในโหมดไม่ระบุตัวตน (Incognito Mode) เพื่อพิสูจน์ว่าผู้ใช้ภายนอกสามารถเปิดเข้าใช้งานและส่งข้อมูลคำสั่งซื้อได้อย่างสมบูรณ์")
set_run_font(r_lk3, font_name="TH Sarabun PSK", size_pt=16)

add_placeholder_box(doc, "ภาพหน้าจอการทดสอบเปิดแอปพลิเคชันในเบราว์เซอร์แบบไม่ระบุตัวตน (Incognito Mode)", "แคปเจอร์หน้าต่าง Incognito Browser ที่แสดงผลหน้าแอปพร้อมแถบ URL ด้านบน")

# บันทึกไฟล์
file_path = "/Users/methas/Desktop/DriveLog/รายงานนำเสนอผลงาน_แอปพลิเคชันหมูกระทะ_ส่วนที่2.docx"
doc.save(file_path)
print("File created successfully:", file_path)
