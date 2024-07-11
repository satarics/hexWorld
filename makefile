# Имя выходного файла
TARGET = hexWorld

# Путь к компилятору RayLua
RAYLUA = ./raylua_e

# Папка с кодом Lua
SRC = src

# Правило для сборки
all: $(TARGET)

$(TARGET): $(MAIN_LUA)
	$(RAYLUA) $(SRC) $(TARGET)

# Правило для очистки
clean:
	rm -f $(TARGET)

# Запуск по умолчанию - сборка проекта
.PHONY: all clean