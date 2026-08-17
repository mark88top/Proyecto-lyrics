# Donaciones

## La regla que hay que respetar

Las guías de App Review 3.2.1(vii) y 3.2.2 distinguen dos casos:

| Quién recibe | Cómo se puede cobrar |
|---|---|
| Organización sin fines de lucro **registrada** | Pago externo permitido (o IAP si preferís) |
| Un desarrollador, un proyecto personal | **Sólo compra in-app** |

CarLyrics cae en el segundo caso: las propinas van al desarrollador. Por lo
tanto **tienen que ser compras in-app**, y la app **no puede** linkear a
PayPal, Ko-fi, Mercado Pago, Patreon ni a una página de donación propia.
Ese link es causa de rechazo, y también lo es mencionar que existe.

Si en algún momento el proyecto pasa a estar bajo una ONG registrada, la
regla cambia y hay que documentar el estatus ante Apple.

## Cómo está implementado

`Core/Donations/TipJar.swift`, con StoreKit 2:

- Tres productos **consumibles** (se pueden comprar muchas veces).
- No desbloquean absolutamente nada. Toda la app sigue igual después de
  donar. Eso es lo que la convierte en una propina legítima y no en un muro
  de pago encubierto.
- Las transacciones se terminan siempre (`transaction.finish()`), incluidas
  las que llegan por `Transaction.updates` desde otro dispositivo o de una
  compra interrumpida. Un consumible que no se termina se vuelve a entregar
  para siempre.

Como no hay nada que restaurar (los consumibles no se restauran), **no hace
falta un botón "Restaurar compras"**. Si en el futuro se agrega cualquier
producto no consumible, ese botón pasa a ser obligatorio (guía 3.1.1).

## Crear los productos en App Store Connect

App Store Connect → tu app → *Monetization → In-App Purchases* → **+**

| Product ID | Tipo | Precio sugerido |
|---|---|---|
| `com.carlyrics.tip.small` | Consumible | Tier 1 |
| `com.carlyrics.tip.medium` | Consumible | Tier 3 |
| `com.carlyrics.tip.large` | Consumible | Tier 10 |

Los IDs tienen que coincidir exactamente con `TipProduct.identifiers`. Si
cambiás el bundle ID de la app, cambiá también estos y el array en el código.

Para cada producto: nombre visible, descripción, y **una captura de la
pantalla de propinas** (Apple la pide para revisar el IAP).

> Los IAP se revisan junto con un build. Si los creás y no los adjuntás a la
> versión, quedan en *Ready to Submit* para siempre y la app sale sin ellos.

## Probar sin cobrar nada

En Xcode el proyecto ya incluye `Sources/CarLyrics/Resources/Products.storekit`.

*Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration* →
elegí `Products.storekit`. Las compras se simulan localmente, sin sandbox y
sin plata de por medio.

## Texto de la pantalla

El copy de `TipJarScreen` es deliberado:

> "No hay anuncios, no hay funciones pagas, no vendemos datos. Si te resulta
> útil y querés que siga creciendo, podés dejar una propina. Es totalmente
> opcional: nada de la app se desbloquea al donar."

Si lo reescribís, mantené las dos afirmaciones clave: que es **opcional** y
que **no desbloquea nada**. Es lo que un revisor busca en esa pantalla.
