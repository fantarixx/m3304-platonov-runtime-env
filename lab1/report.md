# Лабораторная работа № 1. Задача A. Do It Yourself

Все команды выполнены в Linux x86_64.

```text
$ uname -sm
Linux x86_64
```

```text
$ g++ --version
g++ (GCC) 16.2.1 20260810
Copyright (C) 2026 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

## Этап 1. Препроцессинг

Команда создания simple.i:

```sh
g++ -E simple.cpp -o simple.i
```

### 1. Число строк

```text
$ wc -l simple.cpp simple.i
   22 simple.cpp
 1114 simple.i
 1136 total
```

По wc -l: 22 строки в исходнике и 1114 в simple.i.

Команда считает символы перевода строки, поэтому логических строк исходного текста 23 (в последней нету символа переноса)

### 2. Что находится над main

```text
$ rg -n '^int main|^int global_counter|^const int MAGIC|^int square|^int sum_of_squares|^void bump_counter' simple.i
1094:int global_counter = 0;
1095:const int MAGIC = 42;
1097:int square(int x) {
1101:int sum_of_squares(int a, int b) {
1105:void bump_counter() {
1109:int main() {
```

```text
$ head -n 20 simple.i
# 0 "simple.cpp"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3
# 0 "<command-line>" 2
# 1 "simple.cpp"
# 1 "/usr/include/c++/16/cstdio" 1 3
# 46 "/usr/include/c++/16/cstdio" 3
# 1 "/usr/include/c++/16/x86_64-pc-linux-gnu/bits/c++config.h" 1 3
# 37 "/usr/include/c++/16/x86_64-pc-linux-gnu/bits/c++config.h" 3
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wvariadic-macros"

#pragma GCC diagnostic ignored "-Wc++11-extensions"
#pragma GCC diagnostic ignored "-Wc++23-extensions"
# 342 "/usr/include/c++/16/x86_64-pc-linux-gnu/bits/c++config.h" 3
namespace std
{
  typedef long unsigned int size_t;
  typedef long int ptrdiff_t;
```

Перед main находятся определения global_counter, MAGIC и функций
square, sum_of_squares, bump_counter. Основной объём текста выше —
содержимое заголовка `<cstdio>` и включённых им заголовков: объявления функций
стандартной библиотеки, типов, пространств имён и служебные конструкции.
Препроцессор раскрывает #include, обрабатывает условные директивы и макросы.
Строки вида # 1 "..." сохраняют информацию об исходном файле и номерах строк
для дальнейших этапов

### 3. Строка формата

```text
$ rg -n -F 'Result: %d, Counter: %d, Magic: %d' simple.i
1112:    printf("Result: %d, Counter: %d, Magic: %d\n", result, global_counter, MAGIC);
```

Строковый литерал остался внутри вызова printf в main, ближе к концу simple.i.
Его содержимое не изменилось: %d и последовательность \n сохранены.
Препроцессор не форматирует строку и не заменяет текст внутри литерала.
MAGIC в списке аргументов тоже остаётся именем: это константа C++, а не #define

## Этап 2. Компиляция и оптимизации

компилирую результат препроцессинга. -x c++-cpp-output
указывает язык и то, что файл уже прошёл препроцессор (расширение .i обычно
используют для препроцессированного C, а .ii — для C++).

```sh
g++ -S -masm=intel -O0 -x c++-cpp-output simple.i -o simple.s
g++ -S -masm=intel -O2 -x c++-cpp-output simple.i -o simple_O2.s
```

### 4. Сравнение размеров

```text
$ wc -lc simple.s simple_O2.s
 123 2323 simple.s
  76 1492 simple_O2.s
 199 3815 total
```

Размер текста ассемблера уменьшился с 2323 до 1492 байт: в 1,56 раза
(примерно на 35,8%). Число строк уменьшилось со 123 до 76: в 1,62 раза.
Это размеры текстовых файлов с инструкциями и директивами, а не машинного кода.

### 5. Умножение в square без оптимизации

В C++ имена функций кодируются (name mangling), поэтому фактическая метка —
_Z6squarei, а не square. Существенный фрагмент simple.s:

```asm
mov DWORD PTR -4[rbp], edi
mov eax, DWORD PTR -4[rbp]
imul eax, eax
```

Аргумент x сохраняется в стеке и загружается в eax. Инструкция imul eax, eax
умножает x на себя; результат возвращается через eax.

### 6. Передача аргументов sum_of_squares

Фрагмент main в simple.s:

```asm
mov esi, 4
mov edi, 3
call "_Z14sum_of_squaresii"
```

Первый аргумент a = 3 передаётся через edi, второй b = 4 — через esi.
Это младшие 32 бита регистров rdi и rsi. По соглашению System V AMD64 ABI,
применяемому в этом Linux x86_64, первые целочисленные аргументы передаются
в rdi, rsi, rdx, rcx, r8, r9; для int используются их 32-битные части.
Результат int возвращается в eax. Порядок инструкций загрузки не меняет
порядок аргументов: его определяют назначенные им регистры.

### 7. Что произошло с square при -O2

В данном окружении отдельное определение square НЕ исчезло:

```asm
"_Z6squarei":
    ...
    imul edi, edi
    mov eax, edi
    ret
```

Однако вызовы square из sum_of_squares исчезли: умножения встроены прямо
в тело sum_of_squares. В main исчез и вызов sum_of_squares: компилятор
вычислил 3*3 + 4*4 заранее и передаёт printf готовое значение через mov esi, 25.
Вызов bump_counter тоже заменён инструкциями изменения global_counter.
Это встраивание функций (inlining) и вычисление констант при компиляции.
Отдельные определения функций с внешним связыванием сохранены, чтобы их
могли вызывать другие единицы трансляции. Поэтому функция не обязательно исче

## Этап 3. Ассемблирование в объектный файл

Для ручного прохождения всех этапов объект получен из ассемблерного файла:

```sh
g++ -c simple.s -o simple.o
```

Команда из подсказки g++ -c simple.cpp -o simple.o также допустима, но она
за один запуск выполняет препроцессинг, компиляцию и ассемблирование.

```text
$ nm simple.o
000000000000003c T _Z12bump_counterv
000000000000000f T _Z14sum_of_squaresii
0000000000000000 T _Z6squarei
0000000000000000 r _ZL5MAGIC
0000000000000000 B global_counter
0000000000000052 T main
                 U printf
```

```text
$ nm -C simple.o
000000000000003c T bump_counter()
000000000000000f T sum_of_squares(int, int)
0000000000000000 T square(int)
0000000000000000 r MAGIC
0000000000000000 B global_counter
0000000000000052 T main
                 U printf
```

### 8. Почему MAGIC относится к read-only data

MAGIC объявлен const int и имеет постоянное значение 42, поэтому при -O0
его объект находится в секции .rodata — данных только для чтения, а не
в .data, предназначенной для изменяемых инициализированных данных.
В фактическом выводе nm стоит строчная r, а не R: константа пространства
имён в C++ по умолчанию имеет внутреннее связывание. Строчная буква
означает локальный символ, прописная — глобальный. Обозначение _ZL5MAGIC
***деманглируется*** в MAGIC. При -O2 отдельного объекта MAGIC уже нет:
его значение подставлено непосредственно в инструкции.

### 9. Что показывает size

```text
$ size simple.o
   text	   data	    bss	    dec	    hex	filename
    397	      0	      4	    401	    191	simple.o
```

```text
$ size -A simple.o
simple.o  :
section              size   addr
.text                 153      0
.data                   0      0
.bss                    4      0
.rodata                44      0
.comment               28      0
.note.GNU-stack         0      0
.note.gnu.property     48      0
.eh_frame             152      0
Total                 429
```

Обычный вывод size (формат Berkeley) показывает суммарные размеры групп секций
в байтах: text — код и относимые к этой группе неизменяемые данные,
data — инициализированные изменяемые данные, bss — нулевые данные.
dec = 401 — их сумма в десятичном виде, hex = 191 — та же сумма в шестнадцатеричном.
Это не полный размер файла на диске: таблицы символов, релокации и заголовки
объектного файла в эту сумму не входят.

В данном объекте text = 397, data = 0, bss = 4. По подробному выводу
size -A крупнейшие отдельные секции — .text (153 байта машинных инструкций)
и .eh_frame (152 байта метаданных для раскрутки стека). .rodata занимает
44 байта: MAGIC, строка формата с завершающим нулём и выравнивание.
.note.gnu.property занимает 48 байт служебных свойств ELF.
Число text = 397 включает .text, .rodata, .eh_frame и .note.gnu.property.
.comment (28 байт сведений о компиляторе) учитывается в подробном выводе,
но не в обычной сумме text + data + bss.

global_counter инициализирован нулём, поэтому занимает 4 байта в .bss
(символ B в nm); для этой секции в объекте хранится размер, а не массив нулей.
.data пуста: изменяемых объектов с ненулевой начальной инициализацией нет.
В nm буква T обозначает функции в секции кода, U у printf означает,
что её определение должен разрешить компоновщик.

## Этап 4. Компоновка и запуск

Команда компоновки:

```sh
g++ simple.o -o simple
```

Компоновщик объединяет объект со стартовым кодом и подключает необходимые
библиотеки. Ссылка на printf разрешается через стандартную библиотеку C
(при обычной динамической компоновке вызов выполняется через PLT).

### 10. Результат выполнения

```text
$ ./simple
Result: 25, Counter: 1, Magic: 42
```

sum_of_squares(3, 4) возвращает 9 + 16 = 25. Один вызов bump_counter
увеличивает global_counter с 0 до 1, MAGIC равен 42. Код завершения — 0.
