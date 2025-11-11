#!/bin/bash

# Pastikan script dijalankan di direktori addons tempat modul akan dibuat
echo "----------------------------------------------------"
echo "Script Pembuat Template Modul Odoo Kustom Lanjutan (v17 - FINAL FIX JUDUL)"
echo "----------------------------------------------------"

# 1. Meminta Nama Modul dan Judul
read -p "Masukkan nama teknis modul Odoo (misal: custom_project): " MODULE_NAME

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

# --- PEMROSESAN NAMA ---
MODEL_SLUG=$(echo "$MODEL_NAME" | tr '.' '_') 
MODEL_PYTHON_NAME=$(echo "$MODEL_SLUG" | sed 's/_[a-z]/\U&/g' | tr -d '_' | sed 's/^./\U&/') 

# Nama Menu Sub-Menu (mengkapitalisasi setiap kata)
MODEL_LAST_PART=$(echo "$MODEL_NAME" | awk -F'.' '{print $NF}')

# FIX: Mengubah underscore ke spasi, lalu mengkapitalisasi setiap kata (Title Case)
MODEL_TITLE_CAPITALIZED=$(echo ${MODEL_LAST_PART} | tr '_' ' ' | awk '{
    for(i=1; i<=NF; i++) {
        $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2))
    }
    print
}')
# ----------------------

echo "--- Pembuatan Field Model ---"
echo "Format: Nama | Tipe | Judul"
echo "Untuk Selection: Nama|Selection|Judul|key1:Value1;key2:Value2;..."
echo "Tipe: Char, Text, Float, Integer, Boolean, Date, Datetime, Many2one, Selection, dll."
echo "Ketik 'selesai' untuk lanjut."

FIELDS_CONTENT=""
FIELDS_XML_TREE=""
FIELDS_XML_FORM=""
REC_NAME="name" # Default rec_name
i=1
while true; do
    read -p "Field $i (misal: is_active|Boolean|Aktif atau state|Selection|Status|draft:Draft;open:Open): " FIELD_INPUT

    if [[ "$FIELD_INPUT" == "selesai" || "$FIELD_INPUT" == "Selesai" ]]; then
        break
    fi

    # Mencoba memisahkan input menjadi minimal 3 bagian
    IFS='|' read -r FIELD_NAME FIELD_TYPE FIELD_TITLE FIELD_OPTIONS <<< "$FIELD_INPUT"

    if [ -n "$FIELD_NAME" ] && [ -n "$FIELD_TYPE" ] && [ -n "$FIELD_TITLE" ]; then
        LOWER_FIELD_NAME=$(echo "$FIELD_NAME" | tr '[:upper:]' '[:lower:]')
        FIELD_TYPE_LOWER=$(echo "$FIELD_TYPE" | tr '[:upper:]' '[:lower:]')
        
        # Tentukan REC_NAME (field pertama)
        if [ $i -eq 1 ]; then
            REC_NAME=$LOWER_FIELD_NAME
        fi
        
        # Buat Definisi Field Python (menggunakan 4 spasi untuk indentasi)
        FIELD_DEFINITION=""
        if [[ "$FIELD_TYPE_LOWER" == "selection" ]]; then
            # Proses Selection
            SELECTION_TUPLES=""
            IFS=';' read -ra OPTION_ARRAY <<< "$FIELD_OPTIONS"
            for opt in "${OPTION_ARRAY[@]}"; do
                IFS=':' read -r KEY VAL <<< "$opt"
                KEY=$(echo "$KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                VAL=$(echo "$VAL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                # Indentasi tuple 12 spasi (3 level indentasi)
                SELECTION_TUPLES+=$'\n            ('\'$KEY\'', '\'$VAL\''),'
            done
            # Hapus koma terakhir
            SELECTION_TUPLES=$(echo "$SELECTION_TUPLES" | sed '$s/,$//')
            DEFAULT_KEY=$(echo "$FIELD_OPTIONS" | cut -d';' -f1 | cut -d':' -f1)

            # FIX: Ekspansi FIELD_TITLE dan DEFAULT_KEY di Selection dengan indentasi yang benar
            FIELD_DEFINITION=$'\n    '$LOWER_FIELD_NAME$' = fields.Selection(['"$SELECTION_TUPLES"$'\n    ], string="'"$FIELD_TITLE"'", default="'"$DEFAULT_KEY"'")'
        else
            # UNTUK TIPE DATA STANDAR: PERBAIKAN UTAMA DI SINI
            # Pastikan $FIELD_TITLE diekspansi dengan format yang benar
            FIELD_DEFINITION=$'\n    '$LOWER_FIELD_NAME$' = fields.'$FIELD_TYPE$'(string="'"$FIELD_TITLE"'")'
        fi
        
        FIELDS_CONTENT+=$FIELD_DEFINITION

        # Buat Definisi Field XML
        FIELDS_XML_TREE+=$'\n                <field name="'"$LOWER_FIELD_NAME"'" string="'"$FIELD_TITLE"'" />'
        
        XML_WIDGET=""
        if [[ "$FIELD_TYPE_LOWER" == "boolean" ]]; then
            XML_WIDGET=' widget="toggle"'
        fi
        FIELDS_XML_FORM+=$'\n                        <field name="'"$LOWER_FIELD_NAME"'"'"$XML_WIDGET"' />'
        
        i=$((i + 1))
    else
        echo "Input tidak valid. Format harus: Nama|Tipe|Judul (min 3 bagian), atau 4 bagian untuk Selection."
    fi
done

# Jika tidak ada field yang dibuat, tambahkan field 'name' default
if [ -z "$FIELDS_CONTENT" ]; then
    FIELDS_CONTENT=$'\n    name = fields.Char(string="Name", required=True)'
    FIELDS_XML_TREE+=$'\n                <field name="name" />'
    FIELDS_XML_FORM+=$'\n                        <field name="name" />'
    REC_NAME="name"
fi

# 4. Membuat File Utama dan Konten

MODEL_FILENAME=$(echo "$MODEL_SLUG" | tr -d '[:space:]')
MODEL_PYTHON_FILE_NAME=$(echo "$MODEL_NAME" | cut -d'.' -f2)

# File models/model_file.py (INDENTASI 4 SPASI)
cat > models/"$MODEL_PYTHON_FILE_NAME".py <<- EOF
# -*- coding: utf-8 -*-

from odoo import models, fields, api

class $MODEL_PYTHON_NAME(models.Model):
    _name = '$MODEL_NAME'
    _description = '$MODULE_TITLE'
    _rec_name = '$REC_NAME' 

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

# --- Pilihan Editable Tree ---
read -p "Tampilkan List Data sebagai Tree yang Dapat Diedit (y/n)? (Pilih 'n' untuk Form View standar): " EDITABLE_TREE

EDITABLE_ATTRIBUTE=""
if [[ "$EDITABLE_TREE" == "y" || "$EDITABLE_TREE" == "Y" ]]; then
    EDITABLE_ATTRIBUTE=' editable="bottom"'
fi

# 5. Membuat File views/views.xml (Search View menggunakan REC_NAME, Editable Tree)
cat > views/views.xml <<- EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="view_${MODULE_NAME}_${MODEL_SLUG}_tree" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.tree</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <tree string="${MODULE_TITLE} List"$EDITABLE_ATTRIBUTE>
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
                <field name="$REC_NAME"/>
                </search>
        </field>
    </record>
    
    <record id="action_${MODULE_NAME}_${MODEL_SLUG}_no_content" model="ir.actions.act_window">
        <field name="name">${MODULE_TITLE} Data</field>
        <field name="res_model">${MODEL_NAME}</field>
        <field name="view_mode">tree,form</field>
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

# 6. Membuat File views/menu_views.xml (Aksi dan Menu)
cat > views/menu_views.xml <<- EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <menuitem id="menu_${MODULE_NAME}_root" name="$MODULE_TITLE" sequence="10"/>

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
<p>Nama Menu Utama: ${MODEL_TITLE_CAPITALIZED}</p>
EOF

echo "----------------------------------------"
echo "✅ Template Modul Odoo '$MODULE_NAME' berhasil dibuat untuk Odoo 17!"
echo "Nama Main Menu disetel ke '$MODULE_TITLE'."
echo "Nama Sub-Menu disetel ke '$MODEL_TITLE_CAPITALIZED'."
echo "Field rec_name disetel ke '$REC_NAME'."
echo "----------------------------------------"
