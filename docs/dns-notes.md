# DNS и сетевые утилиты

Разбор выполнен на wikipedia.org из WSL (Ubuntu) в Баку.

## dig — узнать IP по имени домена

Компьютеры работают с IP-адресами, люди — с именами.
DNS переводит одно в другое, dig позволяет задать запрос вручную.

```
dig wikipedia.org
```
; <<>> DiG 9.20.24-1ubuntu0.3-Ubuntu <<>> wikipedia.org
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4584
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;wikipedia.org.                 IN      A

;; ANSWER SECTION:
wikipedia.org.          103     IN      A       185.15.59.224

;; Query time: 36 msec
;; SERVER: 10.255.255.254#53(10.255.255.254) (UDP)
;; WHEN: Mon Aug 31 21:22:03 +04 2026
;; MSG SIZE  rcvd: 58
```

Разбор:
- `status: NOERROR` — запрос успешен. NXDOMAIN означал бы, что домена нет.
- `flags: qr rd ra` — ответ; мы просили рекурсию; сервер её умеет.
  Флага `aa` нет, значит ответ пришёл из кэша, а не от владельца зоны.
- ANSWER: `wikipedia.org. 103 IN A 185.15.59.224` — имя, TTL в секундах,
  класс IN, тип записи A (соответствие имени и IPv4), сам адрес.
- `SERVER: 10.255.255.254#53` — резолвер WSL, а не роутер.
  В обычной системе тут был бы адрес вида 192.168.1.1.

Наблюдение про TTL: при первом запуске было 95, при повторном через
5 минут — 103. Не ошибка: старая запись истекла, резолвер запросил
свежую, отсчёт пошёл заново от 300 секунд.

### Кто обслуживает домен

```
dig NS wikipedia.org
```
; <<>> DiG 9.20.24-1ubuntu0.3-Ubuntu <<>> NS wikipedia.org
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 35493
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;wikipedia.org.                 IN      NS

;; ANSWER SECTION:
wikipedia.org.          86400   IN      NS      ns2.wikimedia.org.
wikipedia.org.          86400   IN      NS      ns0.wikimedia.org.
wikipedia.org.          86400   IN      NS      ns1.wikimedia.org.

;; Query time: 195 msec
;; SERVER: 10.255.255.254#53(10.255.255.254) (UDP)
;; WHEN: Mon Aug 31 21:23:52 +04 2026
;; MSG SIZE  rcvd: 106

```
```

Три авторитетных сервера: ns0, ns1, ns2.wikimedia.org — дублирование
на случай отказа. TTL здесь 86400 секунд (сутки) против 300 у A-записи:
список NS меняется годами, а IP сайта может переехать в любой момент.

Query time 195 мс против 36 мс у первого запроса — записи не было
в кэше, резолвер ходил за ней по-настоящему.

## ping — проверить доступность хоста

Шлёт ICMP Echo Request и ждёт Echo Reply.

```
ping -c 4 wikipedia.org
```
PING wikipedia.org (185.15.59.224) 56(84) bytes of data.
64 bytes from text-lb.esams.wikimedia.org (185.15.59.224): icmp_seq=1 ttl=53 time=73.4 ms
64 bytes from text-lb.esams.wikimedia.org (185.15.59.224): icmp_seq=2 ttl=53 time=75.5 ms
64 bytes from text-lb.esams.wikimedia.org (185.15.59.224): icmp_seq=3 ttl=53 time=73.7 ms
64 bytes from text-lb.esams.wikimedia.org (185.15.59.224): icmp_seq=4 ttl=53 time=75.9 ms

--- wikipedia.org ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 73.385/74.641/75.939/1.106 ms
```

```

Разбор:
- `icmp_seq` — номер пакета, пропуск номера означал бы потерю.
- `ttl=53` — сколько хопов пакет ещё может пройти на обратном пути.
  Старт с 64 (стандарт Linux), значит прошёл 11 маршрутизаторов.
- `time=73-76 ms` — round-trip time, туда и обратно.
- `0% packet loss`, `mdev = 1.106 ms` — потерь нет, джиттер низкий,
  канал стабильный.

Имя `text-lb.esams.wikimedia.org`: lb — load balancer,
esams — код дата-центра Wikimedia в Амстердаме. Отсюда и 74 мс.

## traceroute — посмотреть маршрут

Шлёт пакеты с TTL=1, 2, 3… Маршрутизатор, обнуливший TTL, выбрасывает
пакет и возвращает ICMP Time Exceeded — так узнаём его адрес.

### Запуск 1: UDP (по умолчанию)

```
traceroute -m 15 wikipedia.org
```
traceroute to wikipedia.org (185.15.59.224), 15 hops max, 60 byte packets
 1  LAPTOP-47KUE43K.mshome.net (172.20.16.1)  0.879 ms  0.842 ms  0.831 ms
 2  dsldevice.lan (192.168.1.254)  8.520 ms  8.387 ms  8.365 ms
 3  100.80.0.1 (100.80.0.1)  13.260 ms  8.508 ms  13.215 ms
 4  10.254.2.49 (10.254.2.49)  13.258 ms  15.872 ms  13.231 ms
 5  109.235.192.165 (109.235.192.165)  13.670 ms  15.792 ms  13.643 ms
 6  10.240.164.153 (10.240.164.153)  13.666 ms  11.861 ms  11.808 ms
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  * * *
13  * * *
14  * * *
15  * * *
```

```

Видны только 6 хопов, дальше сплошные `* * *`.

### Запуск 2: ICMP

```
sudo traceroute -I -m 20 wikipedia.org
```
[sudo: authenticate] Password:
traceroute to wikipedia.org (185.15.59.224), 20 hops max, 60 byte packets
 1  LAPTOP-47KUE43K.mshome.net (172.20.16.1)  1.531 ms  1.055 ms *
 2  dsldevice.lan (192.168.1.254)  6.456 ms  6.390 ms  6.367 ms
 3  100.80.0.1 (100.80.0.1)  7.641 ms  7.623 ms *
 4  10.254.2.49 (10.254.2.49)  11.974 ms  11.956 ms *
 5  109.235.192.165 (109.235.192.165)  12.680 ms * *
 6  10.240.164.153 (10.240.164.153)  12.705 ms * *
 7  * * *
 8  ae1-380.cr1-esams.wikimedia.org (80.249.209.176)  73.777 ms  75.876 ms  75.857 ms
 9  * * *
10  text-lb.esams.wikimedia.org (185.15.59.224)  75.074 ms  75.131 ms  75.095 ms
```

```

Маршрут раскрылся полностью, до цели 10 хопов.

Разбор маршрута:
- 1 — виртуальный шлюз WSL (172.20.16.1), не реальное устройство
- 2 — домашний роутер, dsldevice.lan
- 3 — 100.80.0.1, диапазон CGNAT: провайдер прячет клиентов
  за общим адресом вместо выдачи публичных IP
- 4, 6 — приватные адреса внутренней сети провайдера
- 5 — 109.235.192.165, первый публичный адрес, магистраль
- 8 — ae1-380.cr1-esams.wikimedia.org, 78 мс. Скачок с 12 до 78 мс
  между 6-м и 8-м хопом — это дорога Азербайджан → Нидерланды.
  cr1 значит core router.
- 10 — text-lb.esams.wikimedia.org, цель достигнута

## Главный вывод

Первый traceroute показал обрыв после 6-го хопа, но связь была в порядке:
ping до того же адреса проходил без потерь за 74 мс. Причина в протоколах —
Linux-овый traceroute по умолчанию шлёт UDP на высокие порты, и транзитные
операторы такое фильтруют. Ping использует ICMP, который пропускают.
Запуск traceroute с флагом -I (тот же ICMP) раскрыл весь маршрут.

Звёздочки в traceroute не означают обрыв связи. Прежде чем искать
поломку, стоит проверить другим протоколом.

## Ещё одно наблюдение

На 9-м хопе задержка 112 мс, на 10-м — 81 мс, хотя пакет прошёл дальше.
Числа в traceroute не накапливаются: каждая строка — отдельное измерение
до конкретного маршрутизатора. Промежуточные узлы отвечают на пробы
по остаточному принципу, их основная работа — пересылать трафик.
Ориентироваться нужно на конечную точку.

## Порядок применения

dig → ping → traceroute. Сначала резолвится ли имя, потом отвечает ли
хост, потом где теряется путь. Это стандартная последовательность
при разборе «сайт не открывается».
