import sqlite3
from datetime import datetime
import flet as ft

def init_db():
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            priority TEXT DEFAULT 'عادي',
            completed INTEGER DEFAULT 0,
            created_at TEXT
        )
    """)
    conn.commit()
    conn.close()

def get_todos():
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    cursor.execute("SELECT id, title, priority, completed, created_at FROM todos ORDER BY id DESC")
    rows = cursor.fetchall()
    conn.close()
    return [{"id": r[0], "title": r[1], "priority": r[2], "completed": bool(r[3]), "created_at": r[4]} for r in rows]

def add_todo_db(title, priority):
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    cursor.execute("INSERT INTO todos (title, priority, completed, created_at) VALUES (?, ?, 0, ?)", (title, priority, now))
    conn.commit()
    conn.close()

def toggle_todo_db(todo_id, completed):
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    cursor.execute("UPDATE todos SET completed = ? WHERE id = ?", (1 if completed else 0, todo_id))
    conn.commit()
    conn.close()

def delete_todo_db(todo_id):
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    cursor.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
    conn.commit()
    conn.close()

def clear_completed_db():
    conn = sqlite3.connect("pytodo.db")
    cursor = conn.cursor()
    cursor.execute("DELETE FROM todos WHERE completed = 1")
    conn.commit()
    conn.close()

def main(page: ft.Page):
    init_db()
    
    page.title = "PyTodo - قائمتي"
    page.rtl = True
    page.theme_mode = ft.ThemeMode.LIGHT
    page.theme = ft.Theme(color_scheme_seed=ft.Colors.TEAL)
    page.padding = 16
    page.spacing = 16

    current_filter = "الكل"

    task_input = ft.TextField(
        hint_text="أضف مهمة جديدة...",
        expand=True,
        border_radius=12,
        autofocus=True,
    )
    
    priority_dropdown = ft.Dropdown(
        value="عادي",
        width=100,
        border_radius=12,
        options=[
            ft.dropdown.Option("عادي"),
            ft.dropdown.Option("مهم"),
            ft.dropdown.Option("عاجل"),
        ],
    )

    todos_list_view = ft.ListView(expand=True, spacing=10)

    total_count_text = ft.Text("0", weight=ft.FontWeight.BOLD, size=18, color=ft.Colors.TEAL)
    active_count_text = ft.Text("0", weight=ft.FontWeight.BOLD, size=18, color=ft.Colors.ORANGE)
    completed_count_text = ft.Text("0", weight=ft.FontWeight.BOLD, size=18, color=ft.Colors.GREEN)

    def toggle_theme(e):
        if page.theme_mode == ft.ThemeMode.LIGHT:
            page.theme_mode = ft.ThemeMode.DARK
            theme_btn.icon = ft.Icons.LIGHT_MODE
        else:
            page.theme_mode = ft.ThemeMode.LIGHT
            theme_btn.icon = ft.Icons.DARK_MODE
        page.update()

    theme_btn = ft.IconButton(
        icon=ft.Icons.DARK_MODE,
        tooltip="تغيير المظهر",
        on_click=toggle_theme,
    )

    def get_filter_style(is_active):
        if is_active:
            return ft.ButtonStyle(
                color=ft.Colors.WHITE,
                bgcolor=ft.Colors.TEAL,
                shape=ft.RoundedRectangleBorder(radius=20),
            )
        else:
            return ft.ButtonStyle(
                color=ft.Colors.TEAL,
                shape=ft.RoundedRectangleBorder(radius=20),
            )

    btn_all = ft.OutlinedButton("الكل", on_click=lambda _: set_filter("الكل"), style=get_filter_style(True))
    btn_active = ft.OutlinedButton("المتبقية", on_click=lambda _: set_filter("المتبقية"), style=get_filter_style(False))
    btn_completed = ft.OutlinedButton("المكتملة", on_click=lambda _: set_filter("المكتملة"), style=get_filter_style(False))

    def set_filter(filter_name):
        nonlocal current_filter
        current_filter = filter_name
        btn_all.style = get_filter_style(current_filter == "الكل")
        btn_active.style = get_filter_style(current_filter == "المتبقية")
        btn_completed.style = get_filter_style(current_filter == "المكتملة")
        update_ui()

    def get_priority_color(priority):
        if priority == "عاجل":
            return ft.Colors.RED_400
        elif priority == "مهم":
            return ft.Colors.ORANGE_400
        return ft.Colors.BLUE_400

    def create_todo_card(todo):
        is_done = todo["completed"]
        priority = todo["priority"]
        
        checkbox = ft.Checkbox(
            value=is_done,
            on_change=lambda e, tid=todo["id"]: handle_toggle(tid, e.control.value),
        )

        title_text = ft.Text(
            todo["title"],
            size=15,
            weight=ft.FontWeight.W_500,
            style=ft.TextStyle(decoration=ft.TextDecoration.LINE_THROUGH if is_done else ft.TextDecoration.NONE),
            color=ft.Colors.GREY_500 if is_done else None,
            expand=True,
        )

        priority_chip = ft.Container(
            content=ft.Text(priority, size=11, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD),
            bgcolor=get_priority_color(priority),
            padding=ft.Padding.only(left=8, top=3, right=8, bottom=3),
            border_radius=10,
        )

        delete_btn = ft.IconButton(
            icon=ft.Icons.DELETE_OUTLINE,
            icon_color=ft.Colors.RED_400,
            tooltip="حذف المهمة",
            on_click=lambda e, tid=todo["id"]: handle_delete(tid),
        )

        return ft.Card(
            elevation=1,
            shape=ft.RoundedRectangleBorder(radius=12),
            content=ft.Container(
                padding=ft.Padding.only(left=12, top=6, right=12, bottom=6),
                content=ft.Row(
                    controls=[
                        checkbox,
                        title_text,
                        priority_chip,
                        delete_btn,
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
            ),
        )

    def update_ui():
        todos = get_todos()
        
        total = len(todos)
        active = sum(1 for t in todos if not t["completed"])
        completed = sum(1 for t in todos if t["completed"])

        total_count_text.value = str(total)
        active_count_text.value = str(active)
        completed_count_text.value = str(completed)

        filtered_todos = todos
        if current_filter == "المتبقية":
            filtered_todos = [t for t in todos if not t["completed"]]
        elif current_filter == "المكتملة":
            filtered_todos = [t for t in todos if t["completed"]]

        todos_list_view.controls.clear()

        if not filtered_todos:
            todos_list_view.controls.append(
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Icon(ft.Icons.TASK_ALT, size=64, color=ft.Colors.TEAL_200),
                            ft.Text("لا توجد مهام حالياً", size=16, color=ft.Colors.GREY_500, weight=ft.FontWeight.W_500),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=8,
                    ),
                    padding=40,
                    alignment=ft.Alignment.CENTER,
                )
            )
        else:
            for todo in filtered_todos:
                todos_list_view.controls.append(create_todo_card(todo))

        page.update()

    def add_task(e):
        title = task_input.value.strip()
        if not title:
            return
        add_todo_db(title, priority_dropdown.value)
        task_input.value = ""
        update_ui()

    def handle_toggle(todo_id, value):
        toggle_todo_db(todo_id, value)
        update_ui()

    def handle_delete(todo_id):
        delete_todo_db(todo_id)
        update_ui()

    def handle_clear_completed(e):
        clear_completed_db()
        update_ui()

    stats_card = ft.Card(
        elevation=2,
        shape=ft.RoundedRectangleBorder(radius=16),
        content=ft.Container(
            padding=16,
            gradient=ft.LinearGradient(
                begin=ft.Alignment.TOP_LEFT,
                end=ft.Alignment.BOTTOM_RIGHT,
                colors=[ft.Colors.TEAL_50, ft.Colors.TEAL_100],
            ),
            border_radius=16,
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_AROUND,
                controls=[
                    ft.Column(
                        controls=[
                            ft.Text("الجميع", size=12, color=ft.Colors.GREY_700),
                            total_count_text,
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=2,
                    ),
                    ft.Container(width=1, height=30, bgcolor=ft.Colors.TEAL_200),
                    ft.Column(
                        controls=[
                            ft.Text("المتبقية", size=12, color=ft.Colors.GREY_700),
                            active_count_text,
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=2,
                    ),
                    ft.Container(width=1, height=30, bgcolor=ft.Colors.TEAL_200),
                    ft.Column(
                        controls=[
                            ft.Text("المكتملة", size=12, color=ft.Colors.GREY_700),
                            completed_count_text,
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=2,
                    ),
                ],
            ),
        ),
    )

    add_btn = ft.FilledButton(
        content=ft.Row([ft.Icon(ft.Icons.ADD, size=20), ft.Text("إضافة")], spacing=4),
        on_click=add_task,
        style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=12)),
    )

    input_row = ft.Row(
        controls=[
            task_input,
            priority_dropdown,
            add_btn,
        ],
        spacing=8,
    )

    header_row = ft.Row(
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        controls=[
            ft.Row(
                controls=[
                    ft.Icon(ft.Icons.CHECKLIST_ROUNDED, color=ft.Colors.TEAL, size=32),
                    ft.Text("مهامي", size=24, weight=ft.FontWeight.BOLD),
                ],
                spacing=8,
            ),
            ft.Row(
                controls=[
                    ft.TextButton(
                        "مسح المكتملة",
                        icon=ft.Icons.CLEANING_SERVICES,
                        icon_color=ft.Colors.RED_400,
                        on_click=handle_clear_completed,
                    ),
                    theme_btn,
                ],
                spacing=4,
            ),
        ],
    )

    filter_row = ft.Row(
        controls=[btn_all, btn_active, btn_completed],
        spacing=8,
        alignment=ft.MainAxisAlignment.CENTER,
    )

    page.add(
        header_row,
        stats_card,
        input_row,
        filter_row,
        ft.Divider(height=1, color=ft.Colors.GREY_300),
        todos_list_view,
    )

    update_ui()

ft.run(main)
