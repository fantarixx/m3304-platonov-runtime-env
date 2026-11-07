# Лабораторная работа № 3

Собрал библиотеку на C и программу на C++ в Linux x86_64.
Исходники находятся в `vector_math.h`, `vector_math.c` и `main.cpp`.
Полный вывод команд — в `commands.txt`.

## Этап 1. Статическая библиотека

```sh
gcc -c vector_math.c -o vector_math.o
ar rcs libmath_static.a vector_math.o
g++ -c main.cpp -o main.o
g++ main.o -L. -lmath_static -o app_static
```

Флаги `ar`: `r` добавляет файлы или заменяет существующие, `c` позволяет
создать архив без предупреждения, `s` создаёт индекс символов.
При повторном запуске объект заменяется, второй копии не появляется:

```text
$ ar rcs libmath_static.a vector_math.o
$ ar t libmath_static.a
vector_math.o
```

В выводе `nm main.o` есть строки:

```text
                 U dot_product
                 U get_lib_version
0000000000000000 T main
```

Имя `main` не кодируется: это особая точка входа программы, которую должен
найти стартовый код. Имена функций библиотеки сохранены благодаря `extern "C"`.

```text
$ ./app_static
Library version: v2.4.1-release
Dot product result: 32
```

Результат: 1·4 + 2·5 + 3·6 = 32. Статически подключена наша библиотека;
системные библиотеки при такой команде могут оставаться динамическими.

## Этап 2. Динамическая библиотека

Сначала выполнил команды без PIC:

```sh
gcc -c vector_math.c -o vector_math_nopic.o
gcc -shared -o libmath_broken.so vector_math_nopic.o
```

Обе команды завершились с кодом 0, ошибки не было. Для этого небольшого
примера на x86_64 имеющиеся перемещения допустимы и без `-fPIC`:
переменная `LIB_VERSION` локальная, обращение к ней идёт относительно RIP.
Это проверено через `readelf -rW vector_math_nopic.o`.
Поэтому ожидаемая в условии ошибка здесь не воспроизвелась.
Для обычной сборки `.so` использовал `-fPIC`, как требуется в задании:

```sh
gcc -c -fPIC vector_math.c -o vector_math_pic.o
gcc -shared -o libmath_dynamic.so vector_math_pic.o
g++ main.o -L. -lmath_dynamic -o app_dynamic
```

```text
$ size app_static app_dynamic
   text    data     bss     dec     hex filename
   2549     672     280    3501     dad app_static
   2494     696     280    3470     d8e app_dynamic
```

`text` уменьшился на 55 байт. Код функций остался в `.so`, в программе
находятся ссылки на него. В `nm app_static` функции отмечены `T`,
а в `nm app_dynamic` — `U`. Разница небольшая из-за служебных данных
динамического связывания. Столбец `text` учитывает не только инструкции.

При запуске указал, где искать библиотеку:

```text
$ LD_LIBRARY_PATH=. ./app_dynamic
Library version: v2.4.1-release
Dot product result: 32
```

## Этап 3. Порядок компоновки

```sh
g++ -L. -lmath_dynamic main.o -o app_wrong_order
g++ main.o -L. -lmath_dynamic -o app_correct
```

В этом окружении обе команды прошли. Для разделяемой библиотеки результат
зависит от режима `--as-needed`. С ним ошибка воспроизводится:

```text
$ g++ -Wl,--as-needed -L. -lmath_dynamic main.o -o app_wrong_as_needed
/usr/bin/ld: main.o: in function `main':
main.cpp:(.text+0x5f): undefined reference to `get_lib_version'
/usr/bin/ld: main.cpp:(.text+0xb0): undefined reference to `dot_product'
collect2: error: ld returned 1 exit status
```

`U` — неразрешённые ссылки, `D` — известные определения,
`E` — включённые в сборку файлы. В начале в `U` ещё нет функций нашей
библиотеки. При `--as-needed` библиотека, указанная первой, не сохраняется
как нужная зависимость. Затем обрабатывается `main.o`: он включается в `E`,
его определения добавляются в `D`, а ссылки на функции — в `U`.
Они остаются неразрешёнными, потому что библиотека уже пройдена.

При правильном порядке сначала появляются ссылки из `main.o`, затем
библиотека их разрешает. Для статического архива `E` содержит извлечённые
объектные файлы; для `.so` речь идёт о сохранении зависимости от библиотеки.

```text
$ g++ -Wl,--as-needed main.o -L. -lmath_dynamic -o app_correct_as_needed
$ LD_LIBRARY_PATH=. ./app_correct_as_needed
Library version: v2.4.1-release
Dot product result: 32
```

## Этап 4. Name mangling

Временно убрал блок `extern "C"` из заголовка и пересобрал C++-файл
под отдельным именем, чтобы сохранить рабочий `main.o`:

```text
$ g++ -c main.cpp -o main_no_extern.o
$ g++ main_no_extern.o -L. -lmath_dynamic -o app_no_extern
/usr/bin/ld: main_no_extern.o: in function `main':
main.cpp:(.text+0x5f): undefined reference to `get_lib_version()'
/usr/bin/ld: main.cpp:(.text+0xb0): undefined reference to `dot_product(int const*, int const*, int)'
collect2: error: ld returned 1 exit status
```

```text
$ nm main_no_extern.o | grep -E 'dot|get_lib'
                 U _Z11dot_productPKiS0_i
                 U _Z15get_lib_versionv
$ nm libmath_dynamic.so | grep -E 'dot|get_lib'
00000000000010f6 T dot_product
00000000000010e9 T get_lib_version
```

C++ закодировал имена с учётом типов параметров, а C сохранил обычные имена.
Они не совпадают, поэтому компоновщик не находит функции.
После проверки вернул `extern "C"` в заголовок. Рабочие программы выводят
версию библиотеки и результат 32.
