# Лабораторная работа № 2

Анализ объектных файлов. Команды выполнены в Linux x86_64 из папки `lab2`.
Полный вывод команд сохранён в `commands.txt`.

## 1. Размеры файлов

```text
$ size core.o legacy.o hotfix.o main.o
   text    data     bss     dec     hex filename
    266    4040   50000   54306    d422 core.o
    172       0       4     176      b0 legacy.o
    127       0       0     127      7f hotfix.o
    118       0       0     118      76 main.o
```

## 2. Большая секция bss

В `core.o` секция `.bss` занимает 50000 байт. По `nm -S core.o` это
локальный массив `large_buffer`. При этом сам файл занимает всего 6200 байт.
Секция имеет тип `NOBITS`: её содержимое не хранится на диске, в ELF указан
только размер. При запуске для неё выделяется обнулённая память.

В условии есть неточность: `dec` — сумма `text + data + bss`, а не размер
файла на диске. Поэтому здесь `dec` большой — 54306 байт.

## 3. Секция со строками

```text
$ readelf -SW core.o
  [ 5] .rodata PROGBITS 0000000000000000 001048 00004c 00 A 0 0 16
```

Нужная секция — `.rodata`, данные только для чтения.
В `legacy.o` и `hotfix.o` её нет, что проверено через `readelf -SW`.

## 4. Секретный токен

Среди результатов `strings -a core.o`:

```text
System Initialized v1.0
FLAG{b1nary_4rch4eology_2026}
%s, Mode: %d
```

Токен: `FLAG{b1nary_4rch4eology_2026}`.

## 5–6. Общие символы

Таблицы получены командами:

```sh
nm core.o legacy.o hotfix.o main.o
readelf -sW core.o legacy.o hotfix.o main.o
```

Повторяются три имени:

| Имя | Файл | Тип nm | Ndx и секция |
|---|---|---|---|
| system_mode | core.o | D | 3, .data |
| system_mode | legacy.o | C | COM |
| system_mode | hotfix.o | C | COM |
| apply_hotfix | hotfix.o | T | 1, .text |
| apply_hotfix | main.o | U | UND |
| print_status | core.o | T | 1, .text |
| print_status | main.o | U | UND |

`D` — инициализированные данные, `C` — COMMON, `T` — код функции,
`U` — ссылка на символ из другого модуля. `COM` и `UND` — специальные
значения индекса, а не обычные секции. COMMON уступает определению в `.data`,
но это не ELF-символ с привязкой WEAK: в `readelf` у него стоит GLOBAL.

## 7. Конфликт system_mode

Во всех трёх файлах размер символа — 4 байта. В `hotfix.c` это массив
`char[4]`. В `core.o` переменная инициализирована, в `legacy.o` она COMMON.
По одной таблице символов точный тип C определить нельзя.

Дополнительно `objdump -dr core.o legacy.o` показывает чтение 32-битного
числа в `core.o` и запись числа 42 в `legacy.o`. Строка формата содержит `%d`.
Это указывает на использование `system_mode` как `int`.
Патч же обращается к той же памяти как к массиву символов.

## 8. Обычная компоновка

```text
$ gcc -fcommon core.o legacy.o hotfix.o main.o -o app
```

Команда завершилась без ошибок и предупреждений. Компоновщик объединил
COMMON-символы с определением из `core.o`. Размеры совпали, а типы C
обычный компоновщик здесь не проверяет.

```text
$ ./app
System Initialized v1.0, Mode: 1
System Initialized v1.0, Mode: 4407873
```

Байты `41 42 43 00` строки `ABC` прочитаны как число `0x00434241`
на этой машине с little-endian. Поэтому получилось 4407873.

## 9. Секция в исполняемом файле

```text
$ nm app | grep system_mode
0000000000004040 D system_mode
```

Переменная оказалась в `.data`: определение из `core.o` имеет приоритет
над COMMON из остальных файлов.

## 10. Запрет COMMON и исправление

```text
$ gcc -fno-common main.o hotfix.o legacy.o core.o -o app_better
```

Эта команда тоже прошла без ошибок. Флаг `-fno-common` действует при
компиляции исходников и не меняет уже готовые объектные файлы.
Чтобы получить ошибку, пересобрал исходный патч в отдельный файл:

```text
$ gcc -fno-common -c hotfix.c -o hotfix_no_common.o
$ gcc -fno-common main.o hotfix_no_common.o legacy.o core.o -o app_no_common
/usr/bin/ld: warning: alignment 1 of normal symbol `system_mode' in hotfix_no_common.o is smaller than 4 used by the common definition in legacy.o
/usr/bin/ld: warning: NOTE: alignment discrepancies can cause real problems.  Investigation is advised.
/usr/bin/ld: core.o:(.data+0x0): multiple definition of `system_mode'; hotfix_no_common.o:(.bss+0x0): first defined here
collect2: error: ld returned 1 exit status
```

Теперь у переменной два обычных определения: в `.data` и `.bss`.
Исправление сохранено в `hotfix_fixed.c`:

```c
extern int system_mode;

void apply_hotfix(void) {
    system_mode = 42;
}
```

`extern` ссылается на существующую переменную, не создавая новую.
Тип согласован с тем, как её используют остальные модули.
Значение 42 взято из поведения `apply_legacy_patch`.

```text
$ gcc -fno-common -c hotfix_fixed.c -o hotfix_fixed.o
$ gcc -fno-common main.o hotfix_fixed.o legacy.o core.o -o app_fixed
$ ./app_fixed
System Initialized v1.0, Mode: 1
System Initialized v1.0, Mode: 42
```

Сборка прошла. В `nm hotfix_fixed.o` переменная имеет тип `U`.
Исходный `legacy.o` по-прежнему содержит COMMON: без его исходника
пересобрать весь проект с полным запретом COMMON нельзя.
