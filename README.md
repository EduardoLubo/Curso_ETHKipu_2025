# Curso_ETHKipu_2025
Repositorio para el curso Ethereum Developer dictado por ETH-Kipu

---- //// ---- ////---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- 

# Smart Contract - Subasta en Solidity

Este es mi codigo para el Modulo 2 del curso de programacion en Solidity 
Se trata de un contrato inteligente de subastas, desarrollado con las funcionalidades requeridas y algunas mejoras adicionales 

---

## Descripcion general

Este contrato permite crear y gestionar una subasta descentralizada en la red Ethereum 
Los usuarios pueden participar enviando ofertas, y al finalizar la subasta se determina un ganador automaticamente 
Los participantes que no ganaron reciben la devolucion de su deposito, descontando una pequena comision para el creador

---

## Funcionalidades principales

- Constructor  
  Permite inicializar la subasta con una descripcion y una duracion en segundos La subasta comienza al momento de desplegar el contrato

- Ofertar (placeBid)  
  Cualquier persona (excepto el dueno del contrato) puede ofertar, siempre que:
  - La subasta este activa
  - Su oferta supere en al menos un 5% la oferta mas alta hasta el momento

  Ademas, si se recibe una oferta valida en los ultimos 10 minutos de la subasta, el tiempo se extiende automaticamente 10 minutos mas

- Mostrar ganador (showWinner)  
  Devuelve la direccion del ganador y el valor de su oferta, una vez que la subasta haya terminado

- Mostrar ofertas (showAllBids)  
  Lista todas las ofertas realizadas, con los montos y las direcciones de cada participante Se incluye paginacion para evitar problemas con el uso de gas

- Devolver depositos (returnAllLosingDeposits)  
  Al finalizar la subasta, todos los participantes que no ganaron reciben la devolucion de su deposito, descontando una comision del 2% que queda para el dueno del contrato

- Reembolsos parciales (partialRefund)  
  Mientras la subasta esta activa, los participantes pueden retirar cualquier monto extra que hayan enviado por encima de su ultima oferta valida

---


## Algunas consideraciones by HEL®

- Se añadio getMetrics() para mostrar los datos actuales de la subasta 
- Se usaron modificadores para evitar repetir condiciones comunes
- Las funciones estan protegidas para evitar que se ejecuten fuera de contexto: 
	egg, acciones que solo pueden hacerse cuando la subasta esta activa o finalizada
- El contrato rechaza cualquier ETH enviado directamente, fuera de las funciones esperadas
- Se utilizan eventos para informar a los usuarios sobre:
  - Nuevas ofertas
  - Finalizacion de la subasta
  - Reembolsos parciales
---
---- //// ---- ////---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ---- //// ----
