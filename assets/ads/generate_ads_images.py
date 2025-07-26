from PIL import Image, ImageDraw, ImageFont

# Placez le fichier DejaVuSans.ttf dans ce dossier (téléchargeable sur https://dejavu-fonts.github.io/)
# ou utilisez une autre police compatible accents si besoin.

colors = [
    (241, 90, 34),    # Orange Bazaria
    (52, 152, 219),   # Bleu
    (46, 204, 113),   # Vert
    (155, 89, 182),   # Violet
    (231, 76, 60),    # Rouge
    (241, 196, 15),   # Jaune
    (44, 62, 80),     # Bleu foncé
]

width, height = 400, 300
bg_color = (245, 245, 245)  # Gris très clair

try:
    font_bazaria = ImageFont.truetype("DejaVuSans.ttf", 38)
    font_pub = ImageFont.truetype("DejaVuSans.ttf", 20)
except:
    print("Police DejaVuSans.ttf non trouvée, la police par défaut sera utilisée (accents non garantis).")
    font_bazaria = ImageFont.load_default()
    font_pub = ImageFont.load_default()

for i, color in enumerate(colors):
    img = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(img)
    text1 = "Bazaria"
    text2 = "Publicité"
    # Mesure des deux textes
    bbox1 = draw.textbbox((0, 0), text1, font=font_bazaria)
    w1 = bbox1[2] - bbox1[0]
    h1 = bbox1[3] - bbox1[1]
    bbox2 = draw.textbbox((0, 0), text2, font=font_pub)
    w2 = bbox2[2] - bbox2[0]
    h2 = bbox2[3] - bbox2[1]
    # Calcul du centrage vertical
    total_height = h1 + h2 + 8  # 8px d'espace entre les deux
    y_start = (height - total_height) // 2
    # Dessin du texte principal
    x1 = (width - w1) // 2
    draw.text((x1, y_start), text1, fill=color, font=font_bazaria)
    # Dessin du texte secondaire
    x2 = (width - w2) // 2
    draw.text((x2, y_start + h1 + 8), text2, fill=color, font=font_pub)
    img.save(f"pub_bazaria_{i+1}.png")
    print(f"Image pub_bazaria_{i+1}.png générée.")

print("Toutes les images ont été générées dans le dossier courant.") 