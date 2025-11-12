#!/bin/bash

# ==============================================
# Script: Buat Modul Odoo v17 KOSONG (NO MODEL)
# HANYA struktur folder + manifest + security + menu
# Model ditambahkan nanti via add_model_to_module.sh
# ==============================================

echo "----------------------------------------------------"
echo "Script Pembuat Modul Odoo Kustom v17 (KOSONG)"
echo "----------------------------------------------------"

# 1. Input Nama Modul
read -p "Masukkan nama teknis modul (misal: custom_project): " MODULE_NAME
if [ -z "$MODULE_NAME" ]; then
    echo "Nama modul tidak boleh kosong."
    exit 1
fi

read -p "Masukkan nama modul yang mudah dibaca (misal: Modul Proyek Kustom): " MODULE_TITLE
if [ -z "$MODULE_TITLE" ]; then
    echo "Judul modul tidak boleh kosong."
    exit 1
fi

# 2. Buat Direktori
if [ -d "$MODULE_NAME" ]; then
    echo "Folder '$MODULE_NAME' sudah ada!"
    exit 1
fi

mkdir -p "$MODULE_NAME"
cd "$MODULE_NAME" || exit 1
echo "Direktori '$MODULE_NAME' dibuat."

# Struktur folder
mkdir -p controllers data models security static/description static/src/js views wizard
touch controllers/__init__.py models/__init__.py wizard/__init__.py

# 3. __init__.py (root)
cat > __init__.py << 'EOF'
# -*- coding: utf-8 -*-
from . import models
from . import wizard
# from . import controllers
EOF

# 4. models/__init__.py (kosong dulu)
cat > models/__init__.py << 'EOF'
# -*- coding: utf-8 -*-
# Model akan ditambahkan via add_model_to_module.sh
EOF

# 5. __manifest__.py
cat > __manifest__.py << EOF
{
    'name': '$MODULE_TITLE',
    'version': '17.0.1.0.0',
    'summary': 'Modul kustom: $MODULE_TITLE',
    'description': '''
        Modul kustom untuk $MODULE_TITLE.
        Model akan ditambahkan secara terpisah.
    ''',
    'author': 'Your Name',
    'category': 'Custom',
    'depends': ['base'],
    'data': [
        'security/ir.model.access.csv',
        'views/menu_views.xml',
    ],
    'installable': True,
    'application': True,
    'license': 'LGPL-3',
}
EOF

# 6. security/ir.model.access.csv (kosong dulu)
cat > security/ir.model.access.csv << 'EOF'
# Akses model akan ditambahkan otomatis saat menambah model
EOF

# 7. views/menu_views.xml (menu root)
cat > views/menu_views.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <menuitem id="menu_${MODULE_NAME}_root" name="$MODULE_TITLE" sequence="10"/>
    <!-- Sub-menu akan ditambahkan saat tambah model -->
</odoo>
EOF

# 8. static/description/index.html
mkdir -p static/description
cat > static/description/index.html << EOF
<section class="oe_container">
    <h1 class="oe_spaced">$MODULE_TITLE</h1>
    <p>Modul kustom kosong. Gunakan <code>add_model_to_module.sh</code> untuk menambah model.</p>
</section>
EOF

# 9. Selesai
echo ""
echo "MODUL KOSONG BERHASIL DIBUAT!"
echo "Nama Modul : $MODULE_TITLE"
echo "Teknis     : $MODULE_NAME"
echo "Lokasi     : $(pwd)"
echo ""
echo "Selanjutnya:"
echo "1. cd $MODULE_NAME"
echo "2. ../add_model_to_module.sh  → untuk tambah model"
echo "========================================"
