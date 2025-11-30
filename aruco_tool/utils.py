import cv2
from functools import reduce

ARUCO_DICT = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
BORDER_SIZE = 1

def get_module_counts(marker_matrix) -> tuple[int, int]:
    on_modules = reduce(lambda x,y: x + sum(y/255), marker_matrix, 0)
    off_modules = reduce(lambda x,y: x + len(y), marker_matrix, 0) - on_modules
    return (on_modules, off_modules)
    
def get_row_module_counts(marker_matrix) -> list[tuple[int,int]]:
    ret = []
    for row in marker_matrix:
        on_modules = reduce(lambda x,y: x+y, row, 0)
        off_modules = len(row)-on_modules
        ret.append((on_modules, off_modules))
    return ret
