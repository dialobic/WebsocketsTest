import json
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk
import os
import copy
from dataclasses import dataclass

@dataclass
class ObjectType:
    defaults: dict

class FileSelector:
    def __init__(self, root):
        self.root = root
        self.root.title("Editor Livelli - Selezione File")
        self.root.geometry("500x444")
        self.selected_file = ""
        self.setup_ui()
    
    def setup_ui(self):
        main_frame = tk.Frame(self.root, padx=20, pady=20)
        main_frame.pack(expand=True, fill=tk.BOTH)
        tk.Label(main_frame, text="Seleziona il file JSON del livello", font=('Arial', 12)).pack(pady=10)
        tk.Button(main_frame, text="Sfoglia...", command=self.select_json_file, width=15).pack(pady=5)
        self.file_label = tk.Label(main_frame, text="Nessun file selezionato", wraplength=400)
        self.file_label.pack(pady=5)
        self.confirm_btn = tk.Button(main_frame, text="Apri Editor", command=self.confirm_selection,
                                    state=tk.DISABLED, width=15)
        self.confirm_btn.pack(pady=10)

    def select_json_file(self):
        filename = filedialog.askopenfilename(title="Seleziona file JSON",
            defaultextension=".json", filetypes=(("File JSON", "*.json"), ("Tutti i file", "*.*")))
        if filename:
            self.selected_file = filename
            self.file_label.config(text=f"File: {filename}")
            self.confirm_btn.config(state=tk.NORMAL)
    
    def confirm_selection(self):
        if self.selected_file:
            self.root.destroy()

class ObjectManager:
    def __init__(self):
        self.object_types = {
            "porta": ObjectType(defaults={"pos": [0, 0], "target": "001", "icona": "empty.png"}),
            "bonus": ObjectType(defaults={"pos": [0, 0], "item": "bonus1", "icona": "bonus.png"}),
            "prendi": ObjectType(defaults={"pos": [0, 0], "item": "oggetto.png", "icona": "oggetto.png"}),
            "metti": ObjectType(defaults={"pos": [0, 0], "item": "oggetto.png", "icona": "empty.png"}),
            "puzzle": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "sposta": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "npc": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "timer": ObjectType(defaults={"pos": [0, 0], "target": "001", "item": "999", "icona": "empty.png"}),
            "cambio": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "deco": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "multi": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "parts": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"}),
            "parts2": ObjectType(defaults={"pos": [0, 0], "target": "", "item": "", "icona": "empty.png"})
        }
    
    def get_defaults(self, object_type: str) -> dict:
        obj_type = self.object_types.get(object_type)
        return obj_type.defaults if obj_type else {}

class LevelEditor:
    def __init__(self, root: tk.Tk, json_file: str):
        self.root = root
        self.current_file = json_file
        self.assets_path = os.path.dirname(json_file)
        self.W, self.H = 1280, 720
        self.CENTER_X, self.CENTER_Y = self.W // 2, self.H // 2
        
        self.rooms_path = os.path.join(self.assets_path, "stanze")
        self.items_path = os.path.join(self.assets_path, "items")
        
        self.object_images = {}
        self.image_cache = {} 
        self.selected_object_id = None
        self.current_room = ""
        self.data = {"stanze": {}}
        
        self.object_manager = ObjectManager()
        self.setup_ui()
        self.load_data()

    def setup_ui(self) -> None:
        file_name = os.path.basename(self.current_file)
        self.root.title(f"Editor - {file_name}")
        self.root.geometry(f"{self.W}x{self.H}")
        self.create_image_panel(self.root)

        self.control_win = tk.Toplevel(self.root)
        self.control_win.title(f"Strumenti - {file_name}")
        self.control_win.geometry("1000x850")
        
        toolbar = tk.Frame(self.control_win, bd=1, relief=tk.RAISED)
        toolbar.pack(side=tk.TOP, fill=tk.X)
        for text, cmd in [("Salva (Compatto)", self.save_to_file), ("Salva con nome", self.save_as), 
                          ("Ricarica", self.reload_file), ("Cambia File", self.change_file)]:
            tk.Button(toolbar, text=text, command=cmd).pack(side=tk.LEFT, padx=2)

        self.control_main_frame = tk.Frame(self.control_win)
        self.control_main_frame.pack(fill=tk.BOTH, expand=True)
        
        self.left_col = tk.Frame(self.control_main_frame, width=200)
        self.left_col.pack(side=tk.LEFT, fill=tk.Y, padx=5, pady=5)
        self.right_col = tk.Frame(self.control_main_frame)
        self.right_col.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        self.create_rooms_panel(self.left_col)
        self.create_edit_panel(self.right_col)
        self.bind_events()

    def create_image_panel(self, parent):
        self.canvas = tk.Canvas(parent, width=self.W, height=self.H, bg="gray50", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

    def create_rooms_panel(self, parent):
        tk.Label(parent, text="Stanze", font=('Arial', 12, 'bold')).pack(pady=5)
        self.rooms_listbox = tk.Listbox(parent, selectmode=tk.SINGLE, font=('Arial', 10))
        self.rooms_listbox.pack(fill=tk.BOTH, expand=True, padx=2)
        for text, command in [("Nuova", self.add_new_room), ("Duplica", self.duplicate_room), ("Elimina", self.delete_room)]:
            tk.Button(parent, text=text, command=command).pack(pady=2, fill=tk.X, padx=2)

    def create_edit_panel(self, parent):
        frame = tk.Frame(parent)
        frame.pack(fill=tk.BOTH, expand=True)
        
        room_frame = tk.LabelFrame(frame, text="Proprietà Stanza", padx=10, pady=10)
        room_frame.pack(fill=tk.X, padx=5, pady=5)
        fields = [("Nome (ID):", "name"), ("Titolo:", "titolo"), ("Sfondo:", "image"), ("Suono:", "suono"), ("Help:", "help")]
        self.room_entries = {}
        for i, (label, key) in enumerate(fields):
            tk.Label(room_frame, text=label).grid(row=i, column=0, sticky=tk.W, pady=2)
            entry = ttk.Entry(room_frame, width=40)
            entry.grid(row=i, column=1, padx=5, pady=2)
            self.room_entries[key] = entry
        
        tk.Button(room_frame, text="Applica Modifiche Stanza", command=self.save_room_changes, bg="#d1ffd1").grid(row=len(fields), columnspan=2, pady=10)

        objects_frame = tk.LabelFrame(frame, text="Oggetti", padx=5, pady=5)
        objects_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        order_f = tk.Frame(objects_frame)
        order_f.pack(fill=tk.X, pady=2)
        tk.Label(order_f, text="Ordina:").pack(side=tk.LEFT, padx=5)
        tk.Button(order_f, text="▲ Su", command=lambda: self.move_object_in_list(-1)).pack(side=tk.LEFT, padx=2)
        tk.Button(order_f, text="▼ Giù", command=lambda: self.move_object_in_list(1)).pack(side=tk.LEFT, padx=2)
        tk.Button(order_f, text="Elimina Oggetto", command=self.delete_object, fg="red").pack(side=tk.RIGHT, padx=5)

        cols = ("tipo", "pos", "target", "item", "icona")
        self.objects_tree = ttk.Treeview(objects_frame, columns=cols, show="headings", selectmode="browse")
        for col in cols: 
            self.objects_tree.heading(col, text=col.capitalize())
            self.objects_tree.column(col, width=85)
        self.objects_tree.pack(fill=tk.BOTH, expand=True)
        
        btn_f = tk.Frame(objects_frame)
        btn_f.pack(fill=tk.X, pady=5)
        for t in self.object_manager.object_types.keys():
            tk.Button(btn_f, text=f"{t}", command=lambda ot=t: self.add_object(ot)).pack(side=tk.LEFT, padx=2)

    def get_clean_data(self):
        """Pulisce ricorsivamente il dizionario rimuovendo campi vuoti"""
        def clean(item):
            if isinstance(item, dict):
                # Rimuove chiavi se il valore è "" o None. 
                # Manteniamo 'oggetti' e 'pos' anche se vuoti per struttura
                return {k: clean(v) for k, v in item.items() if v != "" and v is not None}
            elif isinstance(item, list):
                return [clean(i) for i in item]
            else:
                return item
        return clean(copy.deepcopy(self.data))

    def save_to_file(self, filename=None):
        """Salva in formato minificato (senza spazi o a capo)"""
        fn = filename or self.current_file
        cleaned_data = self.get_clean_data()
        with open(fn, 'w', encoding='utf-8') as f:
            # separators=(',', ':') rimuove gli spazi dopo la virgola e i due punti
            json.dump(cleaned_data, f, separators=(',', ':'), ensure_ascii=False)
        messagebox.showinfo("Salva", "File minificato e pulito correttamente.")

    def save_room_changes(self):
        if not self.current_room: return
        new_name = self.room_entries["name"].get()
        rd = self.data["stanze"][self.current_room]
        rd["titolo"] = self.room_entries["titolo"].get()
        rd["image"] = self.room_entries["image"].get()
        rd["suono"] = self.room_entries["suono"].get()
        rd["help"] = self.room_entries["help"].get()
        
        if new_name != self.current_room:
            self.data["stanze"][new_name] = self.data["stanze"].pop(self.current_room)
            self.current_room = new_name
            self.update_rooms_list()
        
        self.load_room(self.current_room)
        messagebox.showinfo("Info", "Modifiche stanza applicate.")

    def move_object_in_list(self, direction):
        if not self.selected_object_id: return
        idx = self.objects_tree.index(self.selected_object_id)
        new_idx = idx + direction
        oggetti = self.data["stanze"][self.current_room].get("oggetti", [])
        if 0 <= new_idx < len(oggetti):
            oggetti[idx], oggetti[new_idx] = oggetti[new_idx], oggetti[idx]
            self.update_objects_list(select_index=new_idx)
            self.draw_objects()

    def handle_keypress(self, event, key: str, step: int = 1):
        if not self.selected_object_id: return "break"
        idx = self.objects_tree.index(self.selected_object_id)
        obj = self.data["stanze"][self.current_room]["oggetti"][idx]
        x, y = obj["pos"]
        if key == "Left": x -= step
        elif key == "Right": x += step
        elif key == "Up": y -= step
        elif key == "Down": y += step
        obj["pos"] = [x, y]
        self.objects_tree.item(self.selected_object_id, values=(
            obj["tipo"], f"{x}, {y}", obj.get("target",""), obj.get("item",""), obj.get("icona","")
        ))
        self.draw_objects()
        return "break"

    def draw_objects(self):
        if not hasattr(self, 'canvas') or self.current_room not in self.data["stanze"]: return
        self.canvas.delete("object")
        sel_idx = -1
        if self.selected_object_id and self.objects_tree.exists(self.selected_object_id):
            sel_idx = self.objects_tree.index(self.selected_object_id)
        
        for i, obj in enumerate(self.data["stanze"][self.current_room].get("oggetti", [])):
            rel_x, rel_y = obj.get("pos", [0, 0])
            canv_x, canv_y = self.CENTER_X + rel_x, self.CENTER_Y + rel_y
            spessore = 3 if i == sel_idx else 1
            icon_path = self.resolve_image_path(obj.get("icona", ""))
            
            if icon_path and os.path.exists(icon_path):
                if icon_path not in self.image_cache:
                    try: self.image_cache[icon_path] = Image.open(icon_path)
                    except: pass
                if icon_path in self.image_cache:
                    img = self.image_cache[icon_path]
                    tk_img = ImageTk.PhotoImage(img)
                    self.object_images[f"icon_{id(obj)}"] = tk_img
                    self.canvas.create_image(canv_x, canv_y, image=tk_img, tags="object")
                    w, h = img.size
                    self.canvas.create_rectangle(canv_x-w//2, canv_y-h//2, canv_x+w//2, canv_y+h//2, 
                                               outline="#00ff00", width=spessore, tags="object")
                    continue
            self.canvas.create_oval(canv_x-8, canv_y-8, canv_x+8, canv_y+8, fill="red", tags="object")

    def update_objects_list(self, select_index=None):
        self.objects_tree.delete(*self.objects_tree.get_children())
        items = []
        for obj in self.data["stanze"][self.current_room].get("oggetti", []):
            item_id = self.objects_tree.insert("", tk.END, values=(
                obj.get("tipo"), f"{obj.get('pos')[0]}, {obj.get('pos')[1]}",
                obj.get("target", ""), obj.get("item", ""), obj.get("icona", "")
            ))
            items.append(item_id)
        if select_index is not None and 0 <= select_index < len(items):
            self.objects_tree.selection_set(items[select_index])
            self.selected_object_id = items[select_index]

    def load_room(self, name):
        if not name or name not in self.data["stanze"]: return
        self.current_room = name
        self.selected_object_id = None 
        rd = self.data["stanze"][name]
        self.canvas.delete("all")
        ipath = self.resolve_image_path(rd.get("image", ""))
        if ipath:
            try:
                img = Image.open(ipath)
                self.bg_img = ImageTk.PhotoImage(img)
                self.canvas.create_image(self.CENTER_X, self.CENTER_Y, image=self.bg_img)
            except: pass
        for key in ["name","titolo","image","suono","help"]:
            self.room_entries[key].delete(0, tk.END)
            val = name if key == "name" else rd.get(key, "")
            self.room_entries[key].insert(0, val)
        self.update_objects_list()
        self.draw_objects()

    def resolve_image_path(self, name):
        if not name: return ""
        for p in [self.rooms_path, self.items_path, self.assets_path]:
            full = os.path.join(p, name)
            if os.path.exists(full): return full
        return ""

    def load_data(self):
        try:
            with open(self.current_file, 'r', encoding='utf-8') as f: self.data = json.load(f)
            self.update_rooms_list(); self.load_room(sorted(self.data["stanze"].keys())[0])
        except:
            self.data = {"stanze": {"001": {"image": "", "oggetti": []}}}
            self.update_rooms_list(); self.load_room("001")

    def save_as(self):
        fn = filedialog.asksaveasfilename(defaultextension=".json")
        if fn: self.save_to_file(fn); self.current_file = fn

    def reload_file(self): self.image_cache.clear(); self.load_data()
    def change_file(self): self.root.destroy(); main()

    def update_rooms_list(self):
        self.rooms_listbox.delete(0, tk.END)
        for r in sorted(self.data["stanze"].keys()): self.rooms_listbox.insert(tk.END, r)

    def add_new_room(self):
        name = f"{len(self.data['stanze'])+1:03d}"
        self.data["stanze"][name] = {"image": "", "oggetti": [], "titolo": ""}
        self.update_rooms_list(); self.load_room(name)

    def duplicate_room(self):
        name = f"{len(self.data['stanze'])+1:03d}_copy"
        self.data["stanze"][name] = copy.deepcopy(self.data["stanze"][self.current_room])
        self.update_rooms_list(); self.load_room(name)

    def delete_room(self):
        if len(self.data["stanze"]) > 1 and messagebox.askyesno("Elimina", "Eliminare stanza?"):
            del self.data["stanze"][self.current_room]
            self.update_rooms_list(); self.load_room(sorted(self.data["stanze"].keys())[0])

    def add_object(self, obj_type):
        df = self.object_manager.get_defaults(obj_type)
        new_obj = {"tipo": obj_type, "pos": [0,0], "icona": df["icona"], "target": df.get("target",""), "item": df.get("item","")}
        self.data["stanze"][self.current_room]["oggetti"].append(new_obj)
        self.update_objects_list(select_index=len(self.data["stanze"][self.current_room]["oggetti"])-1)
        self.draw_objects()

    def delete_object(self):
        if self.selected_object_id:
            idx = self.objects_tree.index(self.selected_object_id)
            del self.data["stanze"][self.current_room]["oggetti"][idx]
            self.selected_object_id = None
            self.update_objects_list(); self.draw_objects()

    def bind_events(self):
        self.rooms_listbox.bind('<<ListboxSelect>>', self.on_room_select)
        self.objects_tree.bind('<<TreeviewSelect>>', self._on_tree_select)
        self.objects_tree.bind('<Double-1>', self.on_double_click)
        for key in ["Left", "Right", "Up", "Down"]:
            self.root.bind(f"<{key}>", lambda e, k=key: self.handle_keypress(e, k))
            self.root.bind(f"<Shift-{key}>", lambda e, k=key: self.handle_keypress(e, k, 10))

    def on_double_click(self, event):
        region = self.objects_tree.identify_region(event.x, event.y)
        if region != "cell": return
        column = self.objects_tree.identify_column(event.x)
        item = self.objects_tree.identify_row(event.y)
        if column == "#1": return
        x, y, w, h = self.objects_tree.bbox(item, column)
        entry = ttk.Entry(self.objects_tree)
        entry.insert(0, self.objects_tree.set(item, column))
        entry.focus_set()
        entry.place(x=x, y=y, width=w, height=h)
        def save_edit(e=None):
            new_val = entry.get()
            vals = list(self.objects_tree.item(item, 'values'))
            col_idx = int(column[1:]) - 1
            vals[col_idx] = new_val
            self.objects_tree.item(item, values=vals)
            self.update_data_from_tree()
            entry.destroy()
        entry.bind("<Return>", save_edit)
        entry.bind("<FocusOut>", lambda e: entry.destroy())

    def update_data_from_tree(self):
        new_objects = []
        for item in self.objects_tree.get_children():
            v = self.objects_tree.item(item, 'values')
            pos = [int(x.strip()) for x in v[1].split(",")]
            new_objects.append({"tipo": v[0], "pos": pos, "target": v[2], "item": v[3], "icona": v[4]})
        self.data["stanze"][self.current_room]["oggetti"] = new_objects
        self.draw_objects()

    def _on_tree_select(self, e):
        sel = self.objects_tree.selection()
        if sel: 
            self.selected_object_id = sel[0]
            self.draw_objects()

    def on_room_select(self, e):
        sel = self.rooms_listbox.curselection()
        if sel: self.load_room(self.rooms_listbox.get(sel[0]))

def main():
    root = tk.Tk()
    selector = FileSelector(root)
    root.mainloop()
    if selector.selected_file:
        root = tk.Tk()
        LevelEditor(root, selector.selected_file)
        root.mainloop()

if __name__ == "__main__":
    main()
