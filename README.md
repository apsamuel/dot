# shelld ( 🐢 )

a based shell

```bash
tUnit=60
tScale=5
tLen=$((tUnit * tScale))
tortoise_start=0
tortoise_unit=5
tortoise_freq=5
hare_start=10
hare_unit=1
hare_freq=1

function tortoise() {
  start=${tortoise_start:-0}
  length=${tLen:-${tLen}}
}

function hare() {
  start=${${hare_start}:-10}
}
```

## **`NASF`** *(Not Another Shell Framework)*

`ohmyzsh`, `ohmybash`, `OMGGOSH` -- this is not another shell framework

## Declarative

Specify a state, the shell engine will facilitate & maintain it

## Events

shells stream events, you can respond to them
