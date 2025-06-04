// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/* 
Subasta - Trabajo Final para entregar el 10/06/2025
Se requiere un contrato inteligente verificado y publicado en la red de Scroll Sepolia que cumpla con lo siguiente:

Funciones:
> Constructor. Inicializa la subasta con los parametros necesario para su funcionamiento.
> Ofertar: Permite a los participantes ofertar por el articulo. Para que una oferta sea valida debe ser mayor que la mayor oferta actual al menos en 5% y debe realizarse mientras la subasta este activa.
> Mostrar ganador: Muestra el ofertante ganador y el valor de la oferta ganadora.
> Mostrar ofertas: Muestra la lista de ofertantes y los montos ofrecidos.
> Devolver depositos: Al finalizar la subasta se devuelve el deposito a los ofertantes que no ganaron, descontando una comision del 2% para el gas.
> Manejo de depositos: Las ofertas se depositan en el contrato y se almacenan con las direcciones de los ofertantes.

Eventos:
> Nueva Oferta: Se emite cuando se realiza una nueva oferta.
> Subasta Finalizada: Se emite cuando finaliza la subasta.

Funcionalidades avanzadas:
> Reembolso parcial: Los participantes pueden retirar de su deposito el importe por encima de su ultima oferta durante el desarrollo de la subasta.

Consideraciones adicionales:
- Se debe utilizar modificadores cuando sea conveniente.
- Para superar a la mejor oferta la nueva oferta debe ser superior al menos en 5%.
- El plazo de la subasta se extiende en 10 minutos con cada nueva oferta valida. 
     Esta regla aplica siempre a partir de 10 minutos antes del plazo original de la subasta. 
     De esta manera los competidores tienen suficiente tiempo para presentar una nueva oferta si asi lo desean.
- El contrato debe ser seguro y robusto, manejando adecuadamente los errores y las posibles situaciones excepcionales.
- Se deben utilizar eventos para comunicar los cambios de estado de la subasta a los participantes.
- La documentacion del contrato debe ser clara y completa, explicando las funciones, variables y eventos.
*/

// @title SUBASTA 1.0
// @author by Eduardo LUBO - by HEL®

contract Subasta {
    
    // ===== ESTRUCTURAS =====
    // Almacenar informacion de cada oferta
    struct Oferta {
        address ofertante;    // Direccion del ofertante
        uint256 monto;        // Monto de la oferta
        uint256 deposito;     // Total depositado por el ofertante
        uint256 timestamp;    // Momento de creacion de la oferta
    }
    
    // ===== VARIABLES DE ESTADO =====
    address public propietario;                             // Propietario del contrato
    string public descripcionArticulo;                      // Descripcion del articulo subastado
    uint256 public tiempoFinalizacion;                      // Timestamp de finalizacion
    bool public subastaActiva;                              // Estado de la subasta
    bool public subastaFinalizada;                          // Si la subasta ha terminado
    uint256 public constant TIEMPO_EXTENSION = 10 minutes;  // Extension de tiempo
    uint256 public constant MIN_INCREMENTO_PORCENTAJE = 5;  // Incremento minimo 5%
    uint256 public constant COMISION_GAS = 2;               // Comision 2%

    // Ofertas
    Oferta[] public ofertas;                                // Array de todas las ofertas
    mapping(address => uint256) public depositosAcumulados; // Depositos por direccion
    
    // Mejor oferta actual
    address public mejorOfertante;
    uint256 public mejorOferta;

    // ===== CONSTRUCTOR =====    
    constructor( 
        string memory _descripcionArticulo,                 // Descripcion del articulo a subastar
        uint256 _duracionMinutos)                           // Duracion de la subasta en minutos
        {
        require(_duracionMinutos > 0, "La duracion debe ser mayor a cero");
        require(bytes(_descripcionArticulo).length > 0, "Debe proporcionar una descripcion");
        
        propietario = msg.sender;
        descripcionArticulo = _descripcionArticulo;
        tiempoFinalizacion = block.timestamp + (_duracionMinutos * 1 minutes);
        subastaActiva = true;
        subastaFinalizada = false;
    }

    // ===== EVENTOS =====
    // Se dispara cuando se realiza una nueva oferta
    event NuevaOferta(
        address indexed ofertante,
        uint256 monto,
        uint256 timestamp,
        uint256 nuevoTiempoFinalizacion
    );
    
    // Se dispara cuando finaliza la subasta
    event SubastaFinalizada(
        address indexed ganador,
        uint256 montoGanador,
        uint256 timestamp
    );
    
    // Se dispara cuando se devuelve un deposito
    event DevolverDeposito(
        address indexed ofertante,
        uint256 monto,
        uint256 comision
    );
    
    // ===== MODIFICADORES =====
    //  Determina si el propietario puede ejecutar la funcion
    modifier soloPropietario() {
        require(msg.sender == propietario, "Solo el propietario puede ejecutar esta funcion");
        _;
    }
    
    // Determina si la subasta aun esta activa
    modifier subastaEnCurso() {
        require(subastaActiva, "La subasta ya no esta activa");
        require(block.timestamp < tiempoFinalizacion, "La subasta ha finalizado");
        _;
    }
    
    // Determina si la subasta ha finalizado
    modifier subastaTerminada() {
        require(
            !subastaActiva || block.timestamp >= tiempoFinalizacion,
            "La subasta aun esta en curso"
        );
        _;
    }
    
    // ===== FUNCIONES PRINCIPALES =====
    function ofertar() external payable subastaEnCurso {
        require(msg.value > 0, "La Oferta debe ser mayor a cero");
        require(msg.sender != propietario, "El propietario no puede ofertar");
        
        // Calcular el nuevo deposito total del ofertante
        uint256 nuevoDepositoTotal = depositosAcumulados[msg.sender] + msg.value;
        
        // Verificar que la nueva oferta supere el minimo incremento
        uint256 montoMinimoRequerido;
        if (mejorOferta == 0) {
            montoMinimoRequerido = 0;
        } else {
            montoMinimoRequerido = mejorOferta + (mejorOferta * MIN_INCREMENTO_PORCENTAJE / 100);
        }
        
        require(
            nuevoDepositoTotal > montoMinimoRequerido,
            "La oferta ingresada no supera a la mejor oferta (minimo: +5%)"
        );
        
        // Actualizar deposito acumulado
        depositosAcumulados[msg.sender] = nuevoDepositoTotal;
        
        // Actualizar mejor oferta
        mejorOferta = nuevoDepositoTotal;
        mejorOfertante = msg.sender;
        
        // Crear nueva oferta
        Oferta memory nuevaOferta = Oferta({
            ofertante: msg.sender,
            monto: nuevoDepositoTotal,
            deposito: nuevoDepositoTotal,
            timestamp: block.timestamp
        });
        
        ofertas.push(nuevaOferta);
        
        // Extender tiempo si estamos en los ultimos 10 minutos
        uint256 nuevoTiempoFinalizacion = tiempoFinalizacion;
        if (block.timestamp > (tiempoFinalizacion - TIEMPO_EXTENSION)) {
            nuevoTiempoFinalizacion = block.timestamp + TIEMPO_EXTENSION;
            tiempoFinalizacion = nuevoTiempoFinalizacion;
        }
        
        emit NuevaOferta(msg.sender, nuevoDepositoTotal, block.timestamp, nuevoTiempoFinalizacion);
    }
    
    // Regresa el ganador y el valor de la oferta ganadora
    function mostrarGanador() external view subastaTerminada returns (address ganador, uint256 montoGanador) {
        return (mejorOfertante, mejorOferta);
    }
    
    // Muestra la lista de ofertantes y los montos ofrecidos
    function mostrarOfertas() external view returns (Oferta[] memory listaOfertas) {
        return ofertas;
    }
    
    // Finaliza la subasta manualmente (solo propietario)
    function finalizarSubasta() external soloPropietario {
        require(subastaActiva, "La subasta ya fue finalizada");
        subastaActiva = false;
        subastaFinalizada = true;
        emit SubastaFinalizada(mejorOfertante, mejorOferta, block.timestamp);
    }
    
    // Finaliza automaticamente la subasta si el tiempo ha expirado
    function finalizarSubastaAutomatica() external {
        require(block.timestamp >= tiempoFinalizacion, "La subasta aun no ha expirado");
        require(subastaActiva, "La subasta ya fue finalizada");
        subastaActiva = false;
        subastaFinalizada = true;
        emit SubastaFinalizada(mejorOfertante, mejorOferta, block.timestamp);
    }
    
    // Devuelve el deposito a los ofertantes que no ganaron
    function devolverDepositos() external subastaTerminada {
        require(subastaFinalizada, "Debe finalizar la subasta primero");
        require(depositosAcumulados[msg.sender] > 0, "No tienes depositos para retirar");
        require(msg.sender != mejorOfertante, "El ganador no puede retirar depositos");
        uint256 montoADevolver = depositosAcumulados[msg.sender];
        uint256 comision = (montoADevolver * COMISION_GAS) / 100;
        uint256 montoNeto = montoADevolver - comision;

        // Resetear el deposito antes de enviar
        depositosAcumulados[msg.sender] = 0;
        
        // Enviar el monto neto al ofertante
        (bool success, ) = payable(msg.sender).call{value: montoNeto}("");
        require(success, "Error al intentar enviar el reembolso");
        
        // Enviar la comision al propietario
        (bool successComision, ) = payable(propietario).call{value: comision}("");
        require(successComision, "Error al intentarenviar la comision");
        
        emit DevolverDeposito(msg.sender, montoNeto, comision);
    }
    
    //  Permite reembolso parcial, retirar el exceso sobre su ultima oferta
    function reembolsoParcial() external subastaEnCurso {
        require(depositosAcumulados[msg.sender] > 0, "No tienes depositos para retirar");
        
        if (msg.sender != mejorOfertante) {

            // Encontrar la última oferta realizada
            uint256 ultimaOfertaPersonal = 0;
            for (uint256 i = ofertas.length; i > 0; i--) {
                if (ofertas[i-1].ofertante == msg.sender) {
                    ultimaOfertaPersonal = ofertas[i-1].monto;
                    break; 
                }
            }

            // Continuar si tiene una oferta registrada
            require(ultimaOfertaPersonal > 0, "No tienes una Oferta Registrada");

            uint256 depositoTotal = depositosAcumulados[msg.sender];

            // Exceso = Total depositado - ultima oferta
            uint256 excesoDisponible = depositoTotal - ultimaOfertaPersonal ;
            require(excesoDisponible > 0, "No tienes Exceso de Oferta para retirar");

            // Actualizar el depósito acumulado (ultima oferta
            depositosAcumulados[msg.sender] = ultimaOfertaPersonal ;
             
            //uint256 comision = (montoADevolver * COMISION_GAS) / 100;  //Nota del programador: No entendi si debo descontar 2% sobre excedente ?? 
            uint256 comision = 0 ;
            uint256 montoNeto = excesoDisponible - comision ;
            
            (bool success, ) = payable(msg.sender).call{value: montoNeto}("");
            require(success, "Error al enviar el reembolso parcial");
            
            /*  // Solo en caso de cobrar 2% sobre excedente ????   // by HEL®
            (bool successComision, ) = payable(propietario).call{value: comision}("");
            require(successComision, "Error al enviar la comision");
            */ 
                     
            emit DevolverDeposito(msg.sender, montoNeto, comision);
        } else {
            revert("El mejor ofertante no puede solicitar un reembolso parcial");
        }
    }

    // Permite al ganador retirar el articulo y al propietario retirar la ganancia
    function retirarGanancias() external soloPropietario subastaTerminada {
        require(subastaFinalizada, "Debe finalizar la subasta primero");
        require(mejorOfertante != address(0), "No hay un ganador de la Subasta");
        
        uint256 ganancias = mejorOferta;
        mejorOferta = 0; // Evitar doble retiro
        
        (bool success, ) = payable(propietario).call{value: ganancias}("");
        require(success, "Error al transferir las ganancias");
    }
    
    // ===== FUNCIONES DE CONSULTA =====
    
    //  Obtiene informacion general de la subasta
    function informacionSubasta() external view returns (
        string memory descripcion,
        uint256 tiempoRestante,
        uint256 mejorOfertaActual,
        address mejorOfertanteActual,
        bool activa,
        uint256 totalOfertas
    ) {
        uint256 tiempo = 0;
        if (block.timestamp < tiempoFinalizacion) {
            tiempo = tiempoFinalizacion - block.timestamp;
        }
        
        return (
            descripcionArticulo,
            tiempo,
            mejorOferta,
            mejorOfertante,
            subastaActiva && block.timestamp < tiempoFinalizacion,
            ofertas.length
        );
    }
    
    // Consulta el deposito de un ofertante
    function consultarDeposito(address ofertante) external view returns (uint256) {
        return depositosAcumulados[ofertante];
    }
    
    // Calcula el monto minimo para superar la mejor oferta
    function montoMinimoParaSuperar() external view returns (uint256) {
        if (mejorOferta == 0) {
            return 1; // Minimo 1 para la primera oferta
        }
        return mejorOferta + (mejorOferta * MIN_INCREMENTO_PORCENTAJE / 100);
    }
}