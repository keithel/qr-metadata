import sys
import os
from pathlib import Path
from functools import reduce

import qrcode
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QmlElement, QQmlApplicationEngine

def qr_matrix_investigation(qr : qrcode.QRCode, print_ansi=False, print_tty=False):
    matrix = qr.get_matrix()
    print(f"matrix type {type(matrix)}, {len(matrix)} rows, {len(matrix[0])} columns")

    start_row = 0
    start_col = 0
    try:
        start_row, start_col = next((i, j) for i, row in enumerate(matrix) for j, value in enumerate(row) if value)
    except StopIteration:
        print("Matrix is empty!")
        sys.exit(1)

    end_row = 0
    end_col = 0
    end_row, end_col = next((len(matrix)-i-1, len(row)-j+2) for i, row in enumerate(reversed(matrix)) for j, value in enumerate(reversed(row)) if value)
    print(f"starting row, col: ({start_row}, {start_col})")
    print(f"ending row, col  : ({end_row}, {end_col})")
    for row in matrix:
        sys.stdout.write(f"{len(row)},")
    print()
    print(f"matrix[4] == {matrix[4]}")
    print(f"matrix[10] == {matrix[10]}")
    print(f"matrix[11] == {matrix[11]}")

    sub_matrix = [row[start_col:end_col+1] for row in matrix[start_row:end_row+1]]

    white_modules = 0
    black_modules = 0
    border_modules = len(sub_matrix[0]) + 2 + len(sub_matrix)*2

    if print_ansi:
        print("QR BEGIN")
        print("██" * (len(sub_matrix[0]) + 2))
    for row in sub_matrix:
        if print_ansi:
            sys.stdout.write("██")
        for cell in row:
            if cell:
                if print_ansi:
                    sys.stdout.write("  ")
                black_modules += 1
            else:
                if print_ansi:
                    sys.stdout.write("██")
                white_modules += 1
        if print_ansi:
            print("██#")
    if print_ansi:
        print("██" * (len(sub_matrix[0]) + 2))
        print("QR END")

    print("Modules needed:")
    print(f"    White (no border): {white_modules}")
    print(f"    White (border)   : {white_modules + border_modules}")
    print(f"    Black            : {black_modules}")
    print()

    print(f"{len(sub_matrix)}x{len(sub_matrix[0])} == {len(sub_matrix)*len(sub_matrix[0])}")
    if print_tty:
        qr.make()
        qr.print_tty()

    print(f"wxh: {len(qr.modules[0])}x{len(qr.modules)}")
    print(f"wxh: {len(matrix[0])}x{len(matrix)}")
    qr.border = 0
    matrix = qr.get_matrix()
    print(f"wxh: {len(matrix[0])}x{len(matrix)}")

def get_module_counts(qr: qrcode.QRCode) -> tuple[int, int]:
    qr.get_matrix()
    true_modules = reduce(lambda x,y: x + sum(y), qr.modules, 0)
    false_modules = reduce(lambda x,y: x + len(y), qr.modules, 0) - true_modules
    return (true_modules, false_modules)

def get_row_module_counts(qr: qrcode.QRCode) -> list[tuple[int,int]]:
    qr.get_matrix()
    ret = []
    for row in qr.modules:
        true_modules = reduce(lambda x,y: x+y, row, 0)
        false_modules = len(row)-true_modules
        ret.append((true_modules, false_modules))
    return ret

if __name__ == "__main__":
    ssid = "MyAP"
    password = "MyPassword"
    qr_text = f"WIFI:T:WPA;S:{ssid};P:{password};;"

    # app = QGuiApplication(sys.argv)
    # engine = QQmlApplicationEngine()
    # engine.addImageProvider("qr_code", QRCodeImageProvider())    
    # engine.load(os.fspath(Path(__file__).resolve().parent / "main.qml"))

    qr = qrcode.QRCode(version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=10,
            border=4)
    qr.add_data(qr_text)

    rmc = get_row_module_counts(qr)
    print(rmc)
    print(reduce(lambda x,y: (x[0]+y[0], x[1]+y[1]), rmc))
    print(get_module_counts(qr))
    #qr_matrix_investigation(qr, True, False)
