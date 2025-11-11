#!/bin/bash

# Pastikan script dijalankan di direktori addons tempat modul akan dibuat
echo "----------------------------------------------------"
echo "Script Pembuat Template Modul Odoo Kustom Lanjutan (v17 - FINAL)"
echo "----------------------------------------------------"

# 1. Meminta Nama Modul dan Judul
read -p "Masukkan nama teknis modul Odoo (misal: custom_project, danau_indonesia_sejahtera): " MODULE_NAME

if [ -z "$MODULE_NAME" ]; then
    echo "Nama modul tidak boleh kosong. Membatalkan."
    exit 1
fi

read -p "Masukkan nama modul yang mudah dibaca (misal: Modul Proyek Kustom): " MODULE_TITLE

# 2. Membuat Direktori Utama Modul dan Sub-Folder
mkdir -p "$MODULE_NAME"
cd "$MODULE_NAME"

echo "Direktori modul '$MODULE_NAME' berhasil dibuat."
echo "Membuat struktur folder lengkap..."

# Direktori utama
mkdir -p controllers
mkdir -p data
mkdir -p models
mkdir -p security
mkdir -p static/description
mkdir -p static/src/js
mkdir -p views
mkdir -p wizard

# Membuat file __init__.py di sub-folder
touch controllers/__init__.py
touch models/__init__.py
touch wizard/__init__.py

# 3. Mendapatkan Informasi Field Model
read -p "Masukkan nama model teknis (misal: custom.project, default: custom.model.name): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-"custom.model.name"}

# --- PERBAIKAN KRITIS UNTUK STABILITAS ID XML ---
MODEL_SLUG=$(echo "$MODEL_NAME" | tr '.' '_') 
MODEL_PYTHON_NAME=$(echo "$MODEL_SLUG" | sed 's/_[a-z]/\U&/g' | tr -d '_' | sed 's/^./\U&/') 

# --- PERBAIKAN UNTUK JUDUL MENU NAVBAR (FORMATTING BARU) ---
# Menggunakan MODULE_NAME (danau_indonesia_sejahtera) sebagai basis
# Mengganti underscore dengan spasi dan mengkapitalisasi setiap kata.
# Hasil: Danau Indonesia Sejahtera
FORMATTED_MODULE_TITLE=$(echo "$MODULE_NAME" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')

# Mengambil bagian terakhir dari nama model dan mengkapitalisasi (untuk sub-menu)
MODEL_LAST_PART=$(echo "$MODEL_NAME" | awk -F'.' '{print $NF}')
MODEL_TITLE_CAPITALIZED=$(echo ${MODEL_LAST_PART} | sed 's/\(.\)/\U\1/')
# ------------------------------------------------

echo "--- Pembuatan Field Model ---"
echo "Anda dapat membuat field Char, Integer, Float, Boolean, Date, Datetime, Text, Relasional."
echo "Format Sederhana: Nama | Tipe | Judul (misal: name|Char|Nama Proyek)"
echo "Format Relasi: Nama | Tipe (Many2one/One2many/Many2many) | Judul | Model Relasi (misal: partner_id|Many2one|Pelanggan|res.partner)"
echo "Format Selection: Nama | Selection | Judul | Opsi (misal: status|Selection|Status|draft:Draft,done:Done)"
echo "Ketik 'selesai' untuk lanjut."

FIELDS_CONTENT=""
FIELDS_XML_TREE=""
FIELDS_XML_FORM=""
FIRST_FIELD_NAME="" # Variabel untuk menyimpan nama field pertama (untuk _rec_name)
i=1
while true; do
    read -p "Field $i: " FIELD_INPUT

    if [[ "$FIELD_INPUT" == "selesai" || "$FIELD_INPUT" == "Selesai" ]]; then
        break
    fi

    # Menggunakan IFS sementara untuk membaca input
    IFS='|' read -r FIELD_NAME FIELD_TYPE FIELD_TITLE FIELD_OPTIONS <<< "$FIELD_INPUT"

    if [ -n "$FIELD_NAME" ] && [ -n "$FIELD_TYPE" ] && [ -n "$FIELD_TITLE" ]; then
        LOWER_FIELD_NAME=$(echo "$FIELD_NAME" | tr '[:upper:]' '[:lower:]')
        
        # Set field pertama sebagai _rec_name
        if [ -z "$FIRST_FIELD_NAME" ]; then
            FIRST_FIELD_NAME="$LOWER_FIELD_NAME"
        fi

        FIELD_DEFINITION=""
        FIELD_TYPE_CLEAN=$(echo "$FIELD_TYPE" | tr '[:upper:]' '[:lower:]') # Jadikan lowercase

        if [[ "$FIELD_TYPE_CLEAN" == "selection" ]]; then
            # Proses opsi Selection: draft:Draft,done:Done -> [('draft', 'Draft'), ('done', 'Done')]
            PYTHON_OPTIONS=$(echo "$FIELD_OPTIONS" | sed "s/\([^,:]*\):\([^,:]*\)/('\1', '\2')/g" | sed "s/, /, /g")
            PYTHON_OPTIONS="[${PYTHON_OPTIONS}]"
            
            FIELD_DEFINITION=$'\n    '"$LOWER_FIELD_NAME = fields.Selection($PYTHON_OPTIONS, string='$FIELD_TITLE')"

        elif [[ "$FIELD_TYPE_CLEAN" =~ ^(many2one|one2many|many2many)$ ]]; then
            # Tipe Relasi. FIELD_OPTIONS diharapkan berisi nama model relasi.
            RELATED_MODEL=${FIELD_OPTIONS:-"res.partner"} # Default ke res.partner jika kosong
            
            # Khusus O2M dan M2M, harus ada comodel dan inverse field (jika O2M)
            if [[ "$FIELD_TYPE_CLEAN" == "one2many" ]]; then
                # Asumsi field inverse adalah nama model saat ini_id (contoh: custom_project_id)
                INVERSE_FIELD_NAME=$(echo "$MODEL_SLUG" | tr '_' ' ' | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')_id
                FIELD_DEFINITION=$'\n    '"$LOWER_FIELD_NAME = fields.$FIELD_TYPE('$RELATED_MODEL', '$INVERSE_FIELD_NAME', string='$FIELD_TITLE')"
            else
                 FIELD_DEFINITION=$'\n    '"$LOWER_FIELD_NAME = fields.$FIELD_TYPE('$RELATED_MODEL', string='$FIELD_TITLE')"
            fi
            
        else
            # Tipe Sederhana lainnya (Char, Integer, Float, Date, Boolean, dll.)
            FIELD_DEFINITION=$'\n    '"$LOWER_FIELD_NAME = fields.$FIELD_TYPE('$FIELD_TITLE')"
        fi

        # Tambahkan ke Python Model File
        FIELDS_CONTENT+="$FIELD_DEFINITION"

        # Tambahkan ke XML Views
        FIELDS_XML_TREE+=$'\n                <field name="'"$LOWER_FIELD_NAME"'" string="'"$FIELD_TITLE"'" />'
        
        # Penambahan widget toggle untuk Boolean
        WIDGET=""
        if [[ "$FIELD_TYPE_CLEAN" == "boolean" ]]; then
            WIDGET='widget="toggle_button"'
        fi
        
        FIELDS_XML_FORM+=$'\n                    <field name="'"$LOWER_FIELD_NAME"'" '"$WIDGET"' />'
        
        i=$((i + 1))
    else
        echo "Input tidak valid. Format harus: Nama | Tipe | Judul | [Opsi/Model_Relasi]"
    fi
done

# Jika tidak ada field yang dibuat, tambahkan field 'name' default
if [ -z "$FIELDS_CONTENT" ]; then
    FIELDS_CONTENT=$'\n    name = fields.Char(\'Name\', required=True)'
    FIELDS_XML_TREE+=$'\n                <field name="name" />'
    FIELDS_XML_FORM+=$'\n                    <field name="name" />'
    FIRST_FIELD_NAME="name" # Set _rec_name ke 'name'
fi

# 4. Pilihan Default View
echo "----------------------------------------"
echo "Pilih tampilan default saat membuka menu:"
echo "1) Form View (Langsung membuat entri baru)"
echo "2) Tree View (Melihat daftar data)"
read -p "Masukkan pilihan (1/2, default: 2): " DEFAULT_VIEW_CHOICE

VIEW_MODE="tree,form"
if [[ "$DEFAULT_VIEW_CHOICE" == "1" ]]; then
    VIEW_MODE="form,tree"
fi
echo "View Mode disetel ke: $VIEW_MODE"
echo "----------------------------------------"


# 5. Membuat File Utama dan Konten

# File models/model_file.py
MODEL_FILENAME=$(echo "$MODEL_SLUG" | tr -d '[:space:]')
MODEL_PYTHON_FILE_NAME=$(echo "$MODEL_NAME" | cut -d'.' -f2)

cat > models/"$MODEL_PYTHON_FILE_NAME".py <<- EOF
# -*- coding: utf-8 -*-

from odoo import models, fields, api

class $MODEL_PYTHON_NAME(models.Model):
    _name = '$MODEL_NAME'
    _description = '$MODULE_TITLE'
    _rec_name = '$FIRST_FIELD_NAME' 

    # Fields
    $FIELDS_CONTENT
EOF

# File __init__.py (di direktori utama modul)
cat > __init__.py <<- EOF
# -*- coding: utf-8 -*-

from . import models
from . import wizard
# from . import controllers
EOF

# File models/__init__.py (di sub-folder models)
cat > models/__init__.py <<- EOF
# -*- coding: utf-8 -*-

from . import $MODEL_PYTHON_FILE_NAME
EOF


# File __manifest__.py (Manifest/Deskripsi Modul)
cat > __manifest__.py <<- EOF
# -*- coding: utf-8 -*-
{
    'name': "$MODULE_TITLE",
    'version': '17.0.1.0.0',
    'summary': "Ringkasan singkat modul $MODULE_TITLE",
    'description': """
        Deskripsi detail modul $MODULE_TITLE
    """,
    'author': "Avengers",
    'category': 'custom',
    'depends': ['base'], 
    'demo_xml':[],
    'data': [
        'security/ir.model.access.csv', 
        'views/views.xml',        
        'views/menu_views.xml',    
    ],
    'assets': {},
    'active': False,
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
    'sequence': 99,
}
EOF

# File Hak Akses (Security)
MODEL_ID=$(echo "model_${MODEL_SLUG}")
cat > security/ir.model.access.csv <<- EOF
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
access_${MODEL_ID}_user,${MODULE_TITLE} User,${MODEL_ID},base.group_user,1,1,1,0
access_${MODEL_ID}_manager,${MODULE_TITLE} Manager,${MODEL_ID},base.group_system,1,1,1,1
EOF

# 6. Membuat File views/views.xml (Tree dan Form View)
cat > views/views.xml <<- EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="view_${MODULE_NAME}_${MODEL_SLUG}_tree" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.tree</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <tree string="${MODULE_TITLE} List">
                $FIELDS_XML_TREE
            </tree>
        </field>
    </record>

    <record id="view_${MODULE_NAME}_${MODEL_SLUG}_form" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.form</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <form string="${MODULE_TITLE} Form">
                <sheet>
                    <group>
$FIELDS_XML_FORM
                    </group>
                </sheet>
            </form>
        </field>
    </record>

    <record id="view_${MODULE_NAME}_${MODEL_SLUG}_search" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.search</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <search>
                <field name="$FIRST_FIELD_NAME"/>
                </search>
        </field>
    </record>
    
    <record id="action_${MODULE_NAME}_${MODEL_SLUG}_no_content" model="ir.actions.act_window">
        <field name="name">${MODULE_TITLE} Data</field>
        <field name="res_model">${MODEL_NAME}</field>
        <field name="view_mode">$VIEW_MODE</field>
        <field name="help" type="html">
            <p class="o_view_nocontent_smiling_face">
                Buat entri ${MODULE_TITLE} pertama Anda!
            </p><p>
                Gunakan menu ini untuk melacak semua data penting ${MODULE_TITLE}.
            </p>
        </field>
    </record>
</odoo>
EOF

# 7. Membuat File views/menu_views.xml (Aksi dan Menu)
cat > views/menu_views.xml <<- EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <menuitem id="menu_${MODULE_NAME}_root" name="$FORMATTED_MODULE_TITLE" sequence="10"/>

    <menuitem id="menu_${MODULE_NAME}_main" 
              name="$MODEL_TITLE_CAPITALIZED" 
              parent="menu_${MODULE_NAME}_root" 
              sequence="1"/>

    <menuitem id="menu_${MODULE_NAME}_action"
              name="List Data"
              parent="menu_${MODULE_NAME}_main"
              action="action_${MODULE_NAME}_${MODEL_SLUG}_no_content" 
              sequence="1"/>
</odoo>
EOF

# File Deskripsi Modul (README)
cat > static/description/index.html <<- EOF
<h1>$MODULE_TITLE</h1>
<p>Deskripsi lebih lanjut mengenai modul ini.</p>
<p>Model Teknis: ${MODEL_NAME}</p>
<p>Nama Menu Utama: ${FORMATTED_MODULE_TITLE}</p>
<p>Field Utama (_rec_name): ${FIRST_FIELD_NAME}</p>
EOF

echo "----------------------------------------"
echo "✅ Template Modul Odoo '$MODULE_NAME' berhasil dibuat untuk Odoo 17!"
echo "Nama Menu Utama disetel ke '$FORMATTED_MODULE_TITLE'."
echo "Field Utama (_rec_name) disetel ke '$FIRST_FIELD_NAME'."
echo "View Mode disetel ke '$VIEW_MODE'."
echo "----------------------------------------"
