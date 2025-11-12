#!/bin/bash

# ==============================================
# Script: Tambah Model Baru ke Modul Odoo v17
# FULLY FIXED: CSV Security, No Syntax Error, Robust
# ==============================================

echo "=================================="
echo "   TAMBAH MODEL BARU KE MODUL     "
echo "=================================="

# Cek di dalam modul
if [[ ! -f "__manifest__.py" ]]; then
    echo "Error: Jalankan di dalam folder modul!"
    exit 1
fi

MODULE_TITLE=$(grep -oP "'name':\s*'\K[^']+" __manifest__.py | head -1)
MODULE_NAME=$(basename "$PWD")
echo "Modul: $MODULE_NAME ($MODULE_TITLE)"

# Input model
read -p "Nama model teknis (misal: server.category): " MODEL_NAME
[[ -z "$MODEL_NAME" ]] && { echo "Nama model kosong!"; exit 1; }
[[ "$MODEL_NAME" != *.* ]] && { echo "Format: modul.model"; exit 1; }

MODEL_SLUG=$(echo "$MODEL_NAME" | tr '.' '_')
MODEL_PYTHON_NAME=$(echo "$MODEL_SLUG" | sed 's/_[a-z]/\U&/g' | tr -d '_' | sed 's/^./\U&/')
MODEL_LAST_PART=$(echo "$MODEL_NAME" | awk -F'.' '{print $NF}')
MODEL_TITLE_CAP=$(echo "$MODEL_LAST_PART" | tr '_' ' ' | awk '{
    for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))
    print
}')
MODEL_PY_FILE="models/$(echo "$MODEL_NAME" | cut -d'.' -f2).py"

[[ -f "$MODEL_PY_FILE" ]] && { echo "File $MODEL_PY_FILE sudah ada!"; exit 1; }

# Input Fields
echo ""
echo "Input Field: nama|Tipe|Judul|[comodel]"
echo "Ketik 'selesai' untuk lanjut."

FIELDS_CONTENT=""
FIELDS_XML_TREE=""
FIELDS_XML_FORM=""
REC_NAME="name"
i=1

while true; do
    read -p "Field $i: " INPUT
    INPUT=$(echo "$INPUT" | xargs)
    [[ "${INPUT,,}" == "selesai" ]] && break

    IFS='|' read -r FNAME FTYPE FTITLE FCOMODEL <<< "$INPUT"
    FNAME=$(echo "$FNAME" | xargs); FTYPE=$(echo "$FTYPE" | xargs); FTITLE=$(echo "$FTITLE" | xargs); FCOMODEL=$(echo "$FCOMODEL" | xargs)
    LNAME=$(echo "$FNAME" | tr '[:upper:]' '[:lower:]')
    FTYPE_L=$(echo "$FTYPE" | tr '[:upper:]' '[:lower:]')

    [[ -z "$FNAME" || -z "$FTYPE" || -z "$FTITLE" ]] && { echo "Minimal 3 bagian!"; continue; }

    ((i == 1)) && REC_NAME="$LNAME"

    XML_OPTS=""
    FIELD_DEF=""

    case "$FTYPE_L" in
        "many2one")
            [[ -z "$FCOMODEL" ]] && { echo "Many2one butuh comodel!"; continue; }
            FIELD_DEF=$'\n    '"$LNAME"' = fields.Many2one(comodel_name="'"$FCOMODEL"'", string="'"$FTITLE"'")'
            ;;
        "many2many")
            [[ -z "$FCOMODEL" ]] && { echo "Many2many butuh comodel!"; continue; }
            REL="${MODEL_SLUG}_${LNAME}_rel"
            FIELD_DEF=$'\n    '"$LNAME"' = fields.Many2many('
            FIELD_DEF+=$'\n        comodel_name="'"$FCOMODEL"'"'
            FIELD_DEF+=$',\n        relation="'"$REL"'"'
            FIELD_DEF+=$',\n        column1="'"${MODEL_SLUG}"'_id", column2="'"${LNAME}"'_id"'
            FIELD_DEF+=$',\n        string="'"$FTITLE"'"'
            FIELD_DEF+=$'\n    )'
            XML_OPTS=' widget="many2many_tags"'
            ;;
        "selection")
            read -p "  Opsi (key:Value; ...): " OPTS
            [[ -z "$OPTS" ]] && { echo "Opsi kosong!"; continue; }
            TUPLES=""
            DEF=""
            IFS=';' read -ra ARR <<< "$OPTS"
            for o in "${ARR[@]}"; do
                IFS=':' read -r K V <<< "$o"
                K=$(echo "$K" | xargs); V=$(echo "$V" | xargs)
                [[ -z "$DEF" ]] && DEF="$K"
                TUPLES+=$'\n            ("'"$K"'", "'"$V"'"),'
            done
            TUPLES=$(echo "$TUPLES" | sed 's/,$//')
            FIELD_DEF=$'\n    '"$LNAME"' = fields.Selection(['"$TUPLES"$'\n        ], string="'"$FTITLE"'", default="'"$DEF"'")'
            ;;
        "boolean")
            FIELD_DEF=$'\n    '"$LNAME"' = fields.Boolean(string="'"$FTITLE"'")'
            XML_OPTS=' widget="boolean_toggle"'
            ;;
        "date") FIELD_DEF=$'\n    '"$LNAME"' = fields.Date(string="'"$FTITLE"'")'; XML_OPTS=' widget="date"' ;;
        "datetime") FIELD_DEF=$'\n    '"$LNAME"' = fields.Datetime(string="'"$FTITLE"'")'; XML_OPTS=' widget="datetime"' ;;
        *) FIELD_DEF=$'\n    '"$LNAME"' = fields.'"$(echo "$FTYPE_L" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"'(string="'"$FTITLE"'")' ;;
    esac

    FIELDS_CONTENT+="$FIELD_DEF"
    FIELDS_XML_TREE+=$'\n                <field name="'"$LNAME"'"'"$XML_OPTS"' />'
    FIELDS_XML_FORM+=$'\n                        <field name="'"$LNAME"'"'"$XML_OPTS"' />'
    ((i++))
done

[[ -z "$FIELDS_CONTENT" ]] && {
    FIELDS_CONTENT=$'\n    name = fields.Char(string="Name", required=True)'
    FIELDS_XML_TREE=$'\n                <field name="name" />'
    FIELDS_XML_FORM=$'\n                        <field name="name" />'
    REC_NAME="name"
}

read -p "Tree Editable? (y/n): " EDIT
EDIT_ATTR=""
[[ "$EDIT" =~ ^[yY]$ ]] && EDIT_ATTR=' editable="bottom"'

# Buat model
cat > "$MODEL_PY_FILE" << EOF
# -*- coding: utf-8 -*-
from odoo import models, fields

class $MODEL_PYTHON_NAME(models.Model):
    _name = '$MODEL_NAME'
    _description = '$MODEL_TITLE_CAP'
    _rec_name = '$REC_NAME'

$FIELDS_CONTENT
EOF

# Update __init__
grep -q "$(basename "$MODEL_PY_FILE" .py)" models/__init__.py || \
    echo "from . import $(basename "$MODEL_PY_FILE" .py)" >> models/__init__.py

# Buat view
VIEW_FILE="views/${MODEL_SLUG}_views.xml"
cat > "$VIEW_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="view_${MODEL_SLUG}_tree" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.tree</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <tree string="$MODEL_TITLE_CAP List"$EDIT_ATTR>
$FIELDS_XML_TREE
            </tree>
        </field>
    </record>
    <record id="view_${MODEL_SLUG}_form" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.form</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <form><sheet><group>$FIELDS_XML_FORM</group></sheet></form>
        </field>
    </record>
    <record id="view_${MODEL_SLUG}_search" model="ir.ui.view">
        <field name="name">${MODEL_NAME}.search</field>
        <field name="model">${MODEL_NAME}</field>
        <field name="arch" type="xml">
            <search><field name="$REC_NAME"/></search>
        </field>
    </record>
    <record id="action_${MODEL_SLUG}" model="ir.actions.act_window">
        <field name="name">$MODEL_TITLE_CAP</field>
        <field name="res_model">$MODEL_NAME</field>
        <field name="view_mode">tree,form</field>
    </record>
</odoo>
EOF

# Update manifest
grep -q "$VIEW_FILE" __manifest__.py || \
    sed -i "/'data': \[/a\ \ \ \ \ \ \ \ '$VIEW_FILE'," __manifest__.py

# Update menu
if [[ -f "views/menu_views.xml" ]]; then
    grep -q "menu_${MODULE_NAME}_main" views/menu_views.xml || \
        sed -i "/menu_${MODULE_NAME}_root/a\ \ \ \ <menuitem id=\"menu_${MODULE_NAME}_main\" name=\"Main\" parent=\"menu_${MODULE_NAME}_root\" sequence=\"1\"/>" views/menu_views.xml
    cat >> views/menu_views.xml << EOF

    <menuitem id="menu_${MODEL_SLUG}" name="$MODEL_TITLE_CAP" parent="menu_${MODULE_NAME}_main" action="action_${MODEL_SLUG}" sequence="10"/>
EOF
fi

# === FIX SECURITY CSV ===
MODEL_ID="model_${MODEL_SLUG}"
CSV_FILE="security/ir.model.access.csv"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink" > "$CSV_FILE"
fi

if ! head -1 "$CSV_FILE" | grep -q "id,name,model_id:id"; then
    echo "id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink" > "$CSV_FILE"
fi

if ! grep -q "access_${MODEL_ID}_user" "$CSV_FILE"; then
    echo "access_${MODEL_ID}_user,${MODEL_TITLE_CAP} User,${MODEL_ID},base.group_user,1,1,1,0" >> "$CSV_FILE"
    echo "access_${MODEL_ID}_manager,${MODEL_TITLE_CAP} Manager,${MODEL_ID},base.group_system,1,1,1,1" >> "$CSV_FILE"
fi

echo "MODEL BERHASIL DITAMBAH! Restart & Upgrade modul."
