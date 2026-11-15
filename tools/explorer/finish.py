#!/usr/bin/env python3
"""Writes OUT/unused.tsv, redundant.tsv and counts.json from OUT/result.json
(OUT: argv[1], default zig-out/explorer/data), and stores each row's labels
(status, confidence, description, notes) back into result.json."""
import json, os, re, struct, collections, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
A = os.path.join(REPO, "assets")
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(REPO, "zig-out", "explorer", "data")
d = json.load(open(os.path.join(OUT, "result.json")))
rows = d["rows"]
sections = set(d["sections"])
reach = set(d["reach"])

# ---------------------------------------------------------------- guesses (by lower-case stem)
G = {
    # FASE1
    "1ftelefo": "close-up backdrop of the corridor telephone table (scene [1ftelefo] is never entered: no exit or handler leads to it)",
    "1oportba": "bathroom door overlay (135x296), sibling of the 1OPORT2 door",
    "1ovgcor1": "flat blue placeholder overlay for a corridor exit",
    "atende": "tall strip of the boy answering the telephone (never loaded)",
    "1fcozin1": "kitchen backdrop variant (still of a kitchen clip)",
    "1fcozin2": "kitchen backdrop variant (still of a kitchen clip)",
    "1fpisaba": "close-up of the chequered kitchen floor",
    "1fpolar": "open fridge showing a snowy mountain (polar-bear gag backdrop)",
    "1fserra": "kitchen with a cockroach holding a chainsaw (chainsaw gag backdrop)",
    "1fspray": "kitchen: the boy facing the giant cockroach (backdrop of the spray clip)",
    "1fbarcut": "kitchen: the boy facing the giant cockroach (backdrop of the cockroach clip)",
    "1achvcar": "garage backdrop, hand turning the key (still of a clip)",
    "1fchave": "garage backdrop, hand turning the key (scene [1fchave] has no art loaded)",
    "1agarcar": "garage with the red car (still of a clip)",
    "garacar1": "garage with the red car",
    "1fgarag0": "garage, door closed",
    "1fgarag1": "garage, door open onto the road",
    "mao": "tall strip: a hand turning a key (3 frames of 509x1020)",
    "1fcarnbo": "living room with the carnival boy (still of the 1ACARNBO clip)",
    "1fcarnch": "living room with the carnival boy (still of the 1ACARNCH clip)",
    "1fcarniv": "living room with the carnival boy and a potted plant",
    "1oport2": "door overlay (135x295), same file in all six FASE1 folders",
    "1ovport2": "door-frame overlay (80x300), same file in all six FASE1 folders",
    # FASE2
    "2aonifin": "bus stop: the boy beside the orange bus (still of a bus clip)",
    "2fonifin": "bus stop: the boy beside the orange bus",
    "2apolit": "bus cabin: woman driver and a man in a brown jacket",
    "2fpoliti": "bus cabin: woman driver and a man in a brown jacket",
    "2foniexp": "empty night street backdrop (bus explosion clip)",
    "2fpasgei": "bus seats: passengers (boy in red cap plus two men)",
    "2fpaspol": "bus seats: passengers (boy in red cap plus two men)",
    "2salab": "tiny two-frame mouth strip (talking mouth)",
    "2spolm": "tall strip: man in a brown jacket (talking frames)",
    "2spols": "tall strip: close-up of the man's face (talking frames)",
    "2fassass": "car interior with the hitman (backdrop)",
    "2oarmass": "the boy with a gun to his head (red cap)",
    "2sarmboy": "the boy with a gun to his head (red cap)",
    "2sasvi": "tall strip: the hitman's face",
    "2sboym": "tall strip: the boy with a gun to his head (3 poses)",
    "2sboys": "tall strip: the boy's face, shared by 5 FASE2 folders",
    "2aprebo2": "arrest photo: the boy holding number 2469 (still of an arrest clip)",
    "2aprebom": "arrest photo: the boy holding number 2469 (still of an arrest clip)",
    "2fcopbom": "road with a cop waving cones (still of a clip)",
    "2fcopbos": "road with a cop waving cones",
    "2ocopbom": "portrait of the black cop (158x262)",
    "2ocorte1": "blank blue 150x250 placeholder (the 'corte' cut-out), 6 identical copies",
    "2ocapmau": "tiny cop figure on blue",
    "2ocopmau": "portrait of the bad cop (205x236)",
    "2acopmu": "policewoman waving on the road (still of a clip)",
    "2ftracar": "red convertible with the couple (backdrop)",
    "2ocopmu": "portrait of the policewoman (100x204)",
    "2spolf00": "38x49 pixelated close-up face frame",
    "2ffesta2": "street in front of a palace (party scene variant)",
    "2ffesta3": "street in front of a palace (party scene variant)",
    "2ffesta4": "street in front of a palace (party scene variant)",
    "2oonibus": "orange bus on blue (640x256)",
    "2ocorte2": "blank blue 150x250 placeholder (the corte cut-out), 6 identical copies",
    "2ocorte3": "blank blue 150x250 placeholder (the corte cut-out), 6 identical copies",
    "2sgayapr": "tall strip: the boy and the director's heads (talking frames)",
    "2sgays": "tall strip: the boy's face",
    "2sgayv": "tall strip: the director's head",
    "2aloucos": "bus ride: Einstein, the boy and the other passengers",
    "2falain": "bus cabin with the driver and a woman",
    "2fboyloc": "bus window and the street at night",
    "2flouco": "empty bus-window backdrop",
    "2floucos": "bus ride: Einstein, the boy and the other passengers",
    "2fpaslou": "bus seats: Einstein and the other passengers",
    "2salan": "tiny mouth strip",
    "2seins": "tall strip: Einstein's face (talking frames)",
    "2sjesf": "tall strip: Jesus' face (talking frames)",
    "2snapf": "tall strip: Napoleon's face (talking frames)",
    "2amotori": "bus cabin: driver and a woman in a bikini",
    "2fcao": "bus: a man with a bow tie, a dog and a baby",
    "2fonibus": "bus cabin: the driver",
    "2fonimot": "bus cabin: driver and a woman in a bikini",
    "2fvelha": "top-down city map (scene [2fvelha] is never entered)",
    "2fvomit": "the boy being sick (backdrop)",
    "2smotf": "tall strip: the driver's face (talking frames)",
    "2smotv": "tall strip: bus passengers",
    "2spold": "tall strip: hands on the steering wheel",
    "2opononi": "two bus-stop signs on blue",
    "c2carona": "road with the two bus-stop signs ('carona' = hitchhike)",
    "2abarbei": "top-down city map",
    "2abarbes": "top-down city map",
    "2fbarbei": "top-down city map",
    # FASE3
    "3ptax0": "yellow taxi (413x195)",
    "3ssegf": "tiny four-frame strip (29x142)",
    "3sporh": "tall strip: wooden doors of the hall (565x1068)",
    "3fpapdic": "the pope holding up three fingers (backdrop)",
    "3fpapmal": "the pope (backdrop of the pope-punishment scene)",
    "3fpapwin": "the pope in the closet room (scene [3fpapwin] is never entered)",
    "3snvpg": "tall strip: the pope's face (talking frames)",
    "3spama": "tall strip: hands pointing (pope scene)",
    "3spaml": "tall strip: the pope's face (talking frames)",
    "3farmcai": "solid black 640x480 (pixel data identical to ABERTUR.BMP)",
    "3ftorre": "tower, fountain and trees seen from above (scene [3ftorre] is never entered)",
    "3satir": "tall strip: the boy walking (237x3930)",
    "3sporc": "tall strip: prison doors (473x1113)",
    # FASE4
    "4sbarbeb": "tall strip: barman and the boy (bar scene)",
    "4sbarbei": "tall strip: barman and the boy (bar scene)",
    "4sboyt": "tall strip: the boy",
    "4fboydjp": "DJ booth mixing desk (backdrop)",
    "4sboyd": "tall strip: the boy dancing at the DJ booth",
    "4sespb": "tall strip: dark hat shape (esoteric boy?)",
    "6fsaida": "exit scene backdrop (not loaded; scene [6fsaida] plays GAMEOVER.AVI)",
    # P
    "1obibli0": "the bible's scene picture (58x21); loaded only by the port's B51 fix",
    "1obibli2": "bible picture, same bytes as 1OBIBLI0 (an icon-named copy)",
    "1obiblpe": "small (30x10) bible picture",
    "1pbiblia": "bible front cover (38x55)",
    "1pcamis1": "20x20 pixelated shirt icon variant",
    "1poscar4": "Oscar statuette picture variant (54x147)",
    "3abacax1": "pineapple (item picture)",
    "3morceg1": "bat (item picture)",
    "3obasque": "basketball (item picture)",
    "3obinocu": "binoculars (item picture)",
    "3oboneco": "snowman doll (item picture)",
    "3obota": "boot (item picture)",
    "3ocalcul": "calculator (item picture)",
    "3ocaneta": "pen (item picture)",
    "3ocd": "compact disc (item picture)",
    "3ochinel": "flip-flop (item picture)",
    "3ochupet": "pacifier (item picture)",
    "3odepila": "epilator (item picture)",
    "3ofaca": "knife (item picture)",
    "3oferrad": "horseshoe (item picture)",
    "3oguitar": "electric guitar (item picture)",
    "3olivro": "book (item picture)",
    "3orolha": "corks (item picture)",
    "3otenis": "baseball (item picture)",
    "3owisky": "whisky bottle (item picture)",
    "3pbota2": "40x40 inventory icon: boot",
    "3pcd2": "40x40 inventory icon: compact disc",
    "3pchup0": "40x40 inventory icon: pacifier",
    "3pchupt": "40x40 inventory icon: pacifier",
    "3peitos1": "82x69 risque sprite ('peitos'), an extra item picture",
    "3pfaca2": "40x40 inventory icon: knife",
    "3plivro2": "40x40 inventory icon: book",
    "3pmartl2": "40x40 inventory icon: sign / hammer",
    "3prolha2": "40x40 inventory icon: corks",
    "3ptenis2": "40x40 inventory icon: baseball",
    "3pwisky2": "40x40 inventory icon: whisky",
    "ppesorte": "53x39 item picture (a rolled-up object on a keyring)",
    # PAN
    "1pcarta2": "48x35 letter icon, blurred",
    "20pape01": "quiz card 1 (279x371): a trivia question with five answers, red text on crumpled paper; source frame of the 2OASSPAP strip",
    "20pape02": "quiz card 2 (source frame of the 2OASSPAP strip)",
    "20pape03": "quiz card 3 (source frame of the 2OASSPAP strip)",
    "20pape04": "quiz card 4 (source frame of the 2OASSPAP strip)",
    "20pape05": "quiz card 5 (source frame of the 2OASSPAP strip)",
    "20pape06": "quiz card 6 (source frame of the 2OASSPAP strip)",
    "20pape07": "quiz card 7 (source frame of the 2OASSPAP strip)",
    "20pape08": "quiz card 8 (source frame of the 2OASSPAP strip)",
    "20pape09": "quiz card 9 (source frame of the 2OASSPAP strip)",
    "20pape10": "quiz card 10 (source frame of the 2OASSPAP strip)",
    "2opape11": "quiz card: 'Quantos sao os Cassetas?' (source frame of the 2OASSPAP strip)",
    "2oasspap": "PAN copy of the 12-frame quiz-card strip; a different version from the FASE2 one the game loads",
    "2sarbp": "tall tree-and-bush sprite (383x531), bus scene scenery",
    "2sarbu": "tree-and-bush sprite (382x531), bus scene scenery",
    "2sfaix": "8x102 strip (road marking)",
    "2smovl": "tree scenery strip",
    "2smovm": "tree scenery",
    "2smovp": "tree scenery",
    "2svelc": "tiny two-frame face strip",
    "2svelh": "huge strip (303x7680): an old woman ('velha')",
    "3acassf": "wedding-in-prison still (older copy; the game loads the FASE3 version)",
    "3asfwin": "prison brawl still (older copy; the game loads the FASE3 version)",
    "3fstree1": "wedding-in-prison still (same bytes as 3ACASSF)",
    "3fstree2": "prison brawl still (same bytes as 3ASFWIN)",
    "4sboCb": "28x124 strip: lips",
    "amarelar": "button art: 'E ai, vai amarelar? / Vou, e dai? / Nao, porque?' (chicken-out dialogue)",
    "carregar": "menu button 'CARREGAR' (load game)",
    "carro1": "red car sprite (67x33)",
    "carro2": "green car sprite (67x33)",
    "configur": "menu button 'CONFIGURAR'",
    "f1atr": "full-page credits: ATR Multimedia team (page 1)",
    "f2atr": "full-page credits: ATR Multimedia team (page 2)",
    "fagradec": "full-page credits: Agradecimentos (thanks)",
    "fcredcas": "full-page credits: Casseta & Planeta cast",
    "fpersona": "full-page credits: Personagens / Locutores",
    "interf3": "older control-panel art (4 frames of 640x120)",
    "interfac": "older control-panel strip (640x121)",
    "motoserr": "tall strip: the boy and a chainsaw-wielding cockroach (556x3360)",
    "naoporqu": "button art 'NAO, PORQUE?'",
    "onibus": "orange bus sprite (162x55)",
    "options": "options menu backdrop with SALVAR / CARREGAR / CONFIGURAR / SAIR",
    "options2": "options menu on a green backdrop (317x334)",
    "painel2": "older control-panel art (640x480, 4 frames)",
    "sair": "menu button 'SAIR' (quit)",
    "salvajog": "colour-wheel backdrop of the save-game screen",
    "salvar": "menu button 'SALVAR' (save game)",
    "sboyfest": "tall strip: the red car with the boy at the party",
    "statnew": "status bar art (640x40), same bytes in four minigame folders and PAN",
    "untitled": "mostly black 640x480 with a thin line (editor leftover)",
    "vidhist": "screenshot of Video for Windows VidEdit showing an old photo (editing leftover)",
    "vouedai": "button art 'VOU, E DAI?'",
    # AVI
    "2acopsex": "cop clip: the red convertible with the couple (18 frames); the scene plays 2ACOPSES.AVI instead",
    "2afotmau": "arrest-photo clip (24 frames), 203 bytes from 2APREMA2.AVI; same clip under an older name",
    "2atranca": "the red convertible with the couple (23 frames)",
    "3apapmal": "pope clip, 55-frame version (the game plays the 93-frame HD/PAN version)",
    "3apapwin": "pope in the closet room (69 frames); belongs to the unreachable scene [3fpapwin]",
    "4aquenav": "the boy walks to a crashed spaceship/car wreck in a field (20 frames)",
    "carniboy": "carnival-boy clip, 202 bytes from 1ACARNBO.AVI; same clip under an older name",
    "2acopmau": "bad-cop clip, near copy of 2ACOPMAS.AVI under its older name",
    "2acopmu": "policewoman clip, near copy of 2ACOPMUS.AVI under its older name",
    "2aprebo2": "arrest clip, 68 bytes from 2AFOTBOM.AVI",
    "3apapma2": "pope clip, longer 83-frame alternate (scene [3fpapmal2] is never entered)",
    "2aprema2": "bad-cop arrest clip, intact copy (the PAN copy the original plays has ~200 damaged bytes); loaded only by the port fix B42",
    "6fsaida2": "exit scene backdrop variant (scene [6fsaida] plays GAMEOVER.AVI)",
    "mao1": "hand-with-key clip, 11-frame variant of 1AMAO.AVI",
    "portu": "city-map clip, near copy of 2APORTU.AVI (134 bytes differ)",
    # minigames
    "tetrfunn": "alternate Encaixe (tetris) background: black playfield, pharaoh and 'Pontos' panel",
    "tetrfuno": "alternate Encaixe (tetris) background: grey playfield, pharaoh and 'Pontos' panel",
    "naboom": "Invasores: spiky bomb explosion frames (46 KB, tall strip)",
    "cenapeq2": "Xilindro: smaller cave arena variant with the three fighters",
    "sfinterf": "Xilindro: fight HUD, KO banner and two fighter portraits",
    "caixa": "Inferno: falling gift boxes strip",
    "cog1": "Inferno: green mound / bush strip (54x630)",
    "fogog": "Inferno: flame strip",
    "fundon": "Inferno: lava backdrop variant (flat)",
    "fundoo": "Inferno: lava backdrop variant (textured)",
    "garrafa": "Inferno: blue flask (16x22)",
    "margpp": "Inferno: the boy sprite strip (55x346)",
    "marppp": "Inferno: the boy sprite strip, small (32x130)",
    "marpqa": "Inferno: the boy sprite strip (38x260)",
    "presente": "Inferno: gift-box icon (26x27)",
    "statinv": "status bar strip (640x40)",
    "status": "Inferno: yellow status line (640x20)",
    "3fpac": "Sauna: maze backdrop, blue frame variant (earlier Pac-Man)",
    "3fpacman": "Sauna: maze backdrop, dark variant (earlier Pac-Man)",
    "3o1ovo": "Sauna: egg dot icon (15x19)",
    "3spcdb": "Sauna: Pacman/ghost strip, other letter set (down)",
    "3spceb": "Sauna: Pacman/ghost strip, other letter set (left)",
    "3spcmp": "Sauna: small death-strip variant (40x240)",
    "3spcrb": "Sauna: Pacman/ghost strip, other letter set (right)",
    "3spdfp": "Sauna: Pacman/ghost strip, other letter set",
    "3spefp": "Sauna: Pacman/ghost strip, other letter set",
    "3sprfp": "Sauna: Pacman/ghost strip, other letter set",
    "boyfren1": "Sauna: the boy, tall walk strip (165x988) - never used",
    "boyfrent": "Sauna: the boy standing (165x247)",
    "ghost": "Sauna: screenshot of an arcade Pac-Man attract screen (character / nickname) used as reference",
    "ghosta": "Sauna: arcade-style ghost strip, white (40x160)",
    "ghostb": "Sauna: arcade-style ghost strip, orange",
    "ghostc": "Sauna: arcade-style ghost strip, orange",
    "ghostd": "Sauna: arcade-style ghost strip, brown",
    "ghosts": "Sauna: dark playfield with the four ghosts to the right (reference)",
    "labirin": "Sauna: screenshot of an arcade Pac-Man maze (reference)",
    "labirin3": "Sauna: early maze mock-up: yellow walls on black",
    "labirinb": "Sauna: early maze mock-up: yellow walls on white",
    "labirint": "Sauna: early maze mock-up: yellow walls on light blue",
    "pacdown": "Sauna: red Pac-Man placeholder strip (down)",
    "pacleft": "Sauna: red Pac-Man placeholder strip (left)",
    "pacright": "Sauna: red Pac-Man placeholder strip (right)",
    "pacup": "Sauna: red Pac-Man placeholder strip (up)",
    "pbd": "Sauna: Pacman/ghost sprite pair (60x120)",
    "pbe": "Sauna: Pacman/ghost sprite pair (60x120)",
    "ppd": "Sauna: Pacman/ghost sprite pair (60x120)",
    "ppe": "Sauna: Pacman/ghost sprite pair (60x120)",
    "todos": "Sauna: screenshot of an arcade Pac-Man maze with the ghosts (reference)",
    "1fase": "Jardim: the boy's face HUD strip (45x335)",
    "bazuka": "Jardim: bazooka sprite (164x53)",
    "bomba": "Jardim: rocket/bomb sprite (24x52)",
    "brick": "Jardim: brick wall texture (128x600)",
    "bussu": "Jardim: the woman monster 'Bussu' (168x224)",
    "camarao": "Jardim: giant shrimp (156x78)",
    "can3": "Jardim: the woman monster, dithered strip (128x500)",
    "ceu1": "Jardim: sky texture (1920x150)",
    "chao1": "Jardim: sand floor texture",
    "chao3": "Jardim: dark grass floor texture",
    "ctrlsoco": "Jardim: punching hands overlay (80x46)",
    "door": "Jardim: wooden door texture",
    "garden": "Jardim: garden map layout, grey on black",
    "garden2": "Jardim: garden map layout, grey on white",
    "green": "Jardim: hedge texture",
    "greend": "Jardim: dark hedge texture",
    "greenl": "Jardim: light hedge texture",
    "inter": "Jardim: HUD frame variant",
    "inter1": "Jardim: HUD frame variant with the garden view",
    "intrface": "Jardim: HUD frame variant",
    "labintol": "Jardim: HUD strip (640x140)",
    "luiz1": "Jardim: night garden test view (640x360)",
    "luiz2": "Jardim: brick wall texture strip",
    "luiz3": "Jardim: test view with a brick pillar",
    "luiz5": "Jardim: dark hedge test view",
    "maobazuk": "Jardim: first-person bazooka (230x170)",
    "marmore2": "Jardim: marble texture (32x300)",
    "noite1": "Jardim: night sky texture",
    "opcao2a": "Jardim: HUD variant (460 px high)",
    "opcao2b": "Jardim: HUD variant with the view",
    "opcao3o": "Jardim: HUD variant with the view",
    "parede1": "Jardim: wall texture (brick)",
    "parede2": "Jardim: wall texture (grass)",
    "parede3": "Jardim: wall texture (ornament)",
    "parede4": "Jardim: wall texture (red pattern)",
    "parede6": "Jardim: wall texture (dark red)",
    "paredes": "Jardim: stacked wall textures",
    "redbricd": "Jardim: red brick texture, dark",
    "redbrick": "Jardim: red brick texture",
    "setashot": "Jardim: arrow shot sprite",
    "sutishot": "Jardim: bra-shot sprite (the 'sutia' weapon)",
    "walls": "Jardim: hedge wall strips",
    "wallsc3": "Jardim: hedge wall strips (100x3600)",
    "wallsco": "Jardim: hedge wall strips (32x3600)",
    "wallsl": "Jardim: hedge wall strips (128x1800)",
    "wallss": "Jardim: hedge wall strips (64x1800)",
    "wallst": "Jardim: hedge wall strips (64x1800)",
    "1pchees0": "cheeseburger item picture, older version (81x74)",
    "1pembru0": "paper-wrapped parcel item picture, older version (75x105)",
    "1pprese2": "present icon, older version (40x40)",
    "1pvinho0": "wine bottle item picture, older version (88x188)",
    "1pvinho2": "wine bottle icon, older version (40x40)",
    "hand": "mouse cursor: pointing hand (32x32)",
    "left": "mouse cursor: left arrow",
    "right": "mouse cursor: right arrow",
    "lighton": "light-bulb icon from the old demo build",
    "interf3": "older control-panel art (4 frames of 640x120)",
    "1omovete": "bedside-table picture, older version (137x193)",
    "painel": "older control-panel art (640x480, 4 frames)",
    "abert": "solid black 640x480 (same pixels as ABERTUR.BMP, 4 identical copies on the disc)",
    "abertur2": "solid black 640x480 (same pixels as ABERTUR.BMP)",
    "abertura": "solid black 640x480 (same pixels as ABERTUR.BMP)",
    "3fstreet": "solid black 640x480",
}
for k in list(G):
    G[k.lower()] = G[k]


COMMENTED = []
for i, l in enumerate(open(os.path.join(A, "CASSETA.INI"), "rb").read().decode("latin-1").splitlines(), 1):
    if l.startswith(";") and "=" in l and not l.startswith(";Screen=Number") and not l.startswith(";_"):
        COMMENTED.append((i, l.lower()))


def stem(e):
    n = e["path"].replace("\\", "/").rsplit("/", 1)[-1]
    return n[: n.rfind(".")].lower()


def program(e):
    p = e["path"]
    top = p.split("/")[0]
    if e["where"] == "zip":
        return "NOITE (dev archive PAN/WAV/%s)" % top.split("/")[0] if False else "NOITE (zip archive)"
    if top in ("ENCAIXE", "TIRO", "SALGIN", "XILINDRO", "SERIAL", "INV", "INFERNO", "SAUNA", "JARDIM"):
        return top
    return "NOITE"


def folder(e):
    p = e["path"]
    if e["where"] == "zip":
        return p.split("!")[0].replace("PAN/WAV/", "")
    if "/" not in p:
        return "(root)"
    parts = p.split("/")
    if parts[0] in ("PAN",):
        return "PAN/" + parts[1]
    if parts[0].startswith("FASE") and len(parts) > 2:
        return parts[0] + "/" + parts[1]
    return parts[0]


def dims(e):
    i = e.get("info") or {}
    if e["ext"] == ".avi" and i:
        return "%dx%d (%d frames, %s fps)" % (i["w"], i["h"], i["frames"], i["fps"])
    if i.get("w"):
        return "%dx%d" % (i["w"], i["h"])
    if e["ext"] in (".ico", ".cur"):
        p = e.get("real") or os.path.join(A, e["path"])
        with open(p, "rb") as f:
            b = f.read(8)
        w, h = b[6] or 256, b[7] or 256
        return "%dx%d" % (w, h)
    return ""


def guess(e):
    s = stem(e)
    g = G.get(s)
    if e["ext"] == ".ico":
        g = "program icon (the Casseta & Planeta mascot globe), colour variant; identical copy in HD/"
        if e["path"].startswith("HD/"):
            g = "identical copy of the root icon of the same name (installer payload folder)"
    elif e["ext"] == ".cur":
        g = "mouse cursor (hand/left/right) from the old demo build"
    if s == "lighton":
        g = "light-bulb icon from the old demo build"
    if g is None:
        # generic by the naming convention <phase><kind><name>
        if len(s) > 1 and s[1] == "f" and (e.get("info") or {}).get("w") == 640:
            g = "full-screen backdrop"
        elif len(s) > 1 and s[1] == "s":
            g = "sprite strip"
        elif len(s) > 1 and s[1] == "a":
            g = "still or strip of an animation clip"
        elif len(s) > 1 and s[1] == "o":
            g = "scene object / overlay"
        else:
            g = "(not identified)"
    return g


def nearnote(e):
    n = e.get("near")
    if not n:
        return ""
    path, r, st = n
    if r >= 0.999:
        return "same pixel data as %s [%s] (palette/header differ)" % (path, st)
    if r >= 0.9:
        return "near copy of %s [%s]: %d%% of 4 KB blocks equal" % (path, st, round(r * 100))
    return "similar to %s [%s] (%d%% of blocks equal)" % (path, st, round(r * 100))


def classify(e):
    """-> (status label, confidence, note)"""
    st = e["status"]
    s = stem(e)
    note = []
    twins = [t for t in e.get("twins", [])]
    if twins:
        note.append("also: " + "; ".join(sorted(set(t for t in twins)))[:300])
    nn = nearnote(e)
    if nn:
        note.append(nn)
    if st == "used-unreachable":
        sc = ", ".join(e.get("unreach_scenes", []))
        return ("referenced-only-by-unreachable-scene", "referenced, but only by scene [%s] which no exit or handler leads to" % sc, note)
    if st == "fix-only":
        return ("used-only-by-port-fix", "unused in the original (%s)" % e["fix"], note)
    if st == "zip-only":
        return ("in-zip-only", "definitely not read by any program (inside a ZIP; no loose copy)", note)
    if st == "zip-version":
        sn = e.get("same_name", [])
        return ("in-zip-older-version", "definitely not read by any program (inside a ZIP); loose file of the same name is a different version: %s" % ", ".join(sn[:2]), note)
    # unused
    if e.get("fixtwin"):
        note.append("same bytes as %s, which the port's fix loads" % e["fixtwin"])
    # same stem used elsewhere (shadowed copy)
    shadow = [o for o in rows if o["status"] == "used" and o is not e and stem(o) == s and o["ext"] == e["ext"]]
    if shadow:
        note.append("shadowed by used %s (different bytes): the program resolves that one first" % shadow[0]["path"])
    if e["ext"] == ".ico":
        return ("unused", "possibly used: icon for Program Manager / shortcut set up outside the programs; no name reference found", note)
    ex = [h for h in e.get("hits", []) if h != "port src/"]
    if len(s) <= 6:
        ex = [h for h in ex if not h.endswith(".EXE")]
    cm = [(i, l) for (i, l) in COMMENTED if re.search(r"(?<![a-z0-9_])" + re.escape(s) + r"(?![a-z0-9_])", l)]
    if cm:
        note.append("only INI mention is a commented-out line: CASSETA.INI:%d %s" % (cm[0][0], cm[0][1].split(",")[0]))
        ex = [h for h in ex if h != "CASSETA.INI"]
    iniscene = s in sections
    if iniscene:
        note.append("name equals scene section [%s] (the scene exists, its art points elsewhere)" % s)
    if shadow or not ex or iniscene:
        conf = "definitely unused"
    else:
        conf = "probably unused (name text appears in %s but no loader resolves it)" % ", ".join(ex)
    if e["path"].startswith("HD/"):
        conf = "definitely unused"
    return ("unused", conf, note)


out = []
red = []
for e in rows:
    if e["status"] == "redundant":
        red.append(e)
        continue
    if e["status"] not in ("unused", "fix-only", "zip-only", "zip-version", "used-unreachable"):
        continue
    label, conf, note = classify(e)
    e["_label"], e["_conf"], e["_note"] = label, conf, note
    out.append(e)

hdr = ["path", "size", "dimensions", "type", "program", "folder", "status", "confidence", "what_it_is", "other_copies_and_notes"]
with open(os.path.join(OUT, "unused.tsv"), "w") as f:
    f.write("\t".join(hdr) + "\n")
    for e in sorted(out, key=lambda e: (program(e), folder(e), e["path"])):
        f.write("\t".join([
            e["path"], str(e["size"]), dims(e), e["ext"][1:].upper(), program(e), folder(e), e["_label"], e["_conf"],
            guess(e), " | ".join(e["_note"]),
        ]) + "\n")

hdr2 = ["path", "size", "dimensions", "type", "program", "folder", "identical_to_used"]
with open(os.path.join(OUT, "redundant.tsv"), "w") as f:
    f.write("\t".join(hdr2) + "\n")
    for e in sorted(red, key=lambda e: e["path"]):
        f.write("\t".join([e["path"], str(e["size"]), dims(e), e["ext"][1:].upper(), program(e), folder(e), e.get("dup_of", "")]) + "\n")

# ---------------------------------------------------------------- counts
cnt = collections.OrderedDict()
tot = collections.Counter()
for e in rows:
    if e["status"] == "out-of-scope":
        continue
    key = (program(e), folder(e))
    c = cnt.setdefault(key, collections.Counter())
    c["total"] += 1
    c[e["status"]] += 1
    c["bytes"] += e["size"]
    if e["status"] in ("unused", "fix-only", "zip-only", "zip-version", "used-unreachable"):
        c["unused_bytes"] += e["size"]
json.dump([[k[0], k[1], dict(v)] for k, v in cnt.items()], open(os.path.join(OUT, "counts.json"), "w"), indent=1)
print(len(out), "rows in unused.tsv;", len(red), "redundant")

# ---------------------------------------------------------------- labels for the explorer
for e in rows:
    e["what"] = guess(e)
    e["program"] = program(e)
    e["folder"] = folder(e)
    e["dims"] = dims(e)
    if "_label" in e:
        e["label"], e["conf"], e["notes"] = e.pop("_label"), e.pop("_conf"), e.pop("_note")
json.dump(d, open(os.path.join(OUT, "result.json"), "w"), indent=1)
