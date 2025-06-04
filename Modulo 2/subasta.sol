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

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
MEJORAS IMPLEMENTADAS:
02/06 
- Eliminado loop For en reembolsoParcial()
- Optimizados calculos de porcentajes + reduccion gas
- Simplificar gestion de estado subasta
- Agregar paginacion en consultas
- Implementacion limite de gas
- Hacer mas eficientes las estructuras de datos
03/06
- manejar ofertas no deseadas : receive, fallback
04/06
- Correccion para visualizar MontoGanador al finalizar subasta
*/

// @title SUBASTA 1.0.8
// @author by Eduardo LUBO - by HEL®

contract Subasta {
    
    // ===== ESTRUCTURAS =====
	// Almacena informacion de cada oferta

    struct Oferta {
        address ofertante;
        uint256 monto;
        uint256 deposito;
        uint256 timestamp;
    }
    
    // Estado de la Subasta
    enum EstadoSubasta { ACTIVA, FINALIZADA, CANCELADA }
    
    // ===== VARIABLES DE ESTADO =====
    address public propietario;														// Propietario del contrato
    string public descripcionArticulo;												// Descripcion del articulo
    uint256 public tiempoFinalizacion;
    EstadoSubasta public estado;													// Estado de la subasta
    uint256 public constant TIEMPO_EXTENSION = 10 minutes;							

	// MEJORA consumo gas
    uint256 public constant INCREMENTO_FACTOR = 105; 								// +5% = 105/100 
    uint256 public constant COMISION_FACTOR = 98;    								// -2% = 98/100
    uint256 public constant VALOR_CIEN = 100;                                       // 100%

    // No solicitado - Asumo una mejora en uso gas al escalar en cantidad
    uint256 public constant MAX_OFERTAS_CONSULTA = 100;
    uint256 public constant MAX_PARTICIPANTES = 1000;
    uint256 public participantesActuales = 0;

    // MEJORA optimizar el almacenamiento / seguimiento directo
    Oferta[] public ofertas;														// Array de ofertas
	mapping(address => uint256) public depositosAcumulados;							// Depositos por direccion
    mapping(address => uint256) public ultimaOfertaPorUsuario; 						// Ultima oferta
    mapping(address => bool) public yaParticipo; 									// nuevos participantes
    
    // MEJORA oferta actual
    address public mejorOfertante;
    uint256 public mejorOferta;

    // NUEVO: Variables para ver Monto del Ganador Subasta
    uint256 public montoGanadorFinal;                                               // Preserva el monto ganador original
    bool public gananciasRetiradas;                                                 // Indica si ya se retiraron las ganancias

    // ===== CONSTRUCTOR =====    
    constructor( 
        string memory _descripcionArticulo,
        uint256 _duracionMinutos) {
        require(_duracionMinutos > 0, "La duracion debe ser mayor a cero");
        require(bytes(_descripcionArticulo).length > 0, "Debe proporcionar una descripcion");
        
        propietario = msg.sender;
        descripcionArticulo = _descripcionArticulo;
        tiempoFinalizacion = block.timestamp + (_duracionMinutos * 1 minutes);
        estado = EstadoSubasta.ACTIVA;
    }

    // ===== EVENTOS  =====
    // MEJORA Eventos con menos parametros
    event NuevaOferta(address indexed ofertante, uint256 monto, uint256 nuevoTiempo);
    event SubastaFinalizada(address indexed ganador, uint256 monto);
    event DevolverDeposito(address indexed ofertante, uint256 monto, uint256 comision);
    
    // ===== MODIFICADORES =====
    modifier soloPropietario() {
        require(msg.sender == propietario, "Solo el propietario puede ejecutar esta funcion");
        _;
    }
    
    // MEJORA Modificador simplificado con enum
    modifier soloActiva() {
        require(estado == EstadoSubasta.ACTIVA && block.timestamp < tiempoFinalizacion, "Subasta inactiva");
        _;
    }
    
    modifier soloFinalizada() {
        require(estado == EstadoSubasta.FINALIZADA || block.timestamp >= tiempoFinalizacion, "Subasta no finalizada");
        _;
    }
    
    // MEJORA Cantidad de participantes
    modifier limitarParticipantes() {
        if (!yaParticipo[msg.sender]) {
            require(participantesActuales < MAX_PARTICIPANTES, "Cantidad Maxima de Participantes alcanzado");
            _;
        } else {
            _;
        }
    }
    
    // ===== FUNCIONES PRINCIPALES =====
    
    // MEJORA Función ofertar() optimizada
    function ofertar() external payable soloActiva limitarParticipantes {
        require(msg.value > 0, "La Oferta debe ser mayor a cero");
        require(msg.sender != propietario, "El propietario no puede ofertar");
        
        // Seguimiento nuevos participantes
        if (!yaParticipo[msg.sender]) {
            yaParticipo[msg.sender] = true;
            participantesActuales++;
        }
        
        uint256 nuevoDepositoTotal = depositosAcumulados[msg.sender] + msg.value;
        
        // MEJORA Calculo optimizado sin división repetitiva
        uint256 montoMinimoRequerido = (mejorOferta * INCREMENTO_FACTOR) / VALOR_CIEN;
        
        require(nuevoDepositoTotal > montoMinimoRequerido, "La oferta no supera el minimo requerido (+5%)");
        
        // Updates optimizados
        depositosAcumulados[msg.sender] = nuevoDepositoTotal;
        ultimaOfertaPorUsuario[msg.sender] = nuevoDepositoTotal; 
        mejorOferta = nuevoDepositoTotal;
        mejorOfertante = msg.sender;
        
        // Crear nueva oferta (solo si es necesario para historial)
        ofertas.push(Oferta({
            ofertante: msg.sender,
            monto: nuevoDepositoTotal,
            deposito: nuevoDepositoTotal,
            timestamp: block.timestamp
        }));
        
        // Funcion auxiliar para extender tiempo
        uint256 nuevoTiempo = _extenderTiempoSiNecesario();
        
        emit NuevaOferta(msg.sender, nuevoDepositoTotal, nuevoTiempo);
    }
    
    // MEJORA Funcion auxiliar para extender tiempo
    function _extenderTiempoSiNecesario() private returns (uint256) {
        if (block.timestamp > (tiempoFinalizacion - TIEMPO_EXTENSION)) {
            tiempoFinalizacion = block.timestamp + TIEMPO_EXTENSION;
        }
        return tiempoFinalizacion;
    }
    
    function mostrarGanador() external view soloFinalizada returns (address ganador, uint256 montoGanador) {
        return (mejorOfertante, montoGanadorFinal);
    }
    
    // MEJORA mostrarOfertas() con paginacion
    function mostrarOfertas(uint256 inicio, uint256 cantidad) 
        external view returns (Oferta[] memory resultado, uint256 total) {
        require(inicio < ofertas.length, "Inicio invalido");
        require(cantidad <= MAX_OFERTAS_CONSULTA, "Cantidad excede limite");
        
        uint256 fin = inicio + cantidad;
        if (fin > ofertas.length) {
            fin = ofertas.length;
        }
        
        resultado = new Oferta[](fin - inicio);
        for (uint256 i = inicio; i < fin; i++) {
            resultado[i - inicio] = ofertas[i];
        }
        
        return (resultado, ofertas.length);
    }
    
    // MEJORA Funcion para obtener todas las ofertas 
    function mostrarTodasOfertas() external view returns (Oferta[] memory) {
        require(ofertas.length <= MAX_OFERTAS_CONSULTA, "Demasiadas ofertas para mostrar (Usar funcion mostrarOfertas)");
        return ofertas;
    }
    
    function finalizarSubasta() external soloPropietario {
        require(estado == EstadoSubasta.ACTIVA, "La subasta ya fue finalizada");
        estado = EstadoSubasta.FINALIZADA;
        emit SubastaFinalizada(mejorOfertante, mejorOferta);
    }
    
    function finalizarSubastaAutomatica() external {
        require(block.timestamp >= tiempoFinalizacion, "La subasta aun no ha expirado");
        require(estado == EstadoSubasta.ACTIVA, "La subasta ya fue finalizada");
        estado = EstadoSubasta.FINALIZADA;
        emit SubastaFinalizada(mejorOfertante, mejorOferta);
    }
    
    // MEJORA devolverDepositos() con calculo optimizado
    function devolverDepositos() external soloFinalizada {
        require(estado == EstadoSubasta.FINALIZADA, "Debe finalizar la subasta primero");
        require(depositosAcumulados[msg.sender] > 0, "No tienes depositos para retirar");
        require(msg.sender != mejorOfertante, "El ganador no puede retirar depositos");
        
        uint256 montoADevolver = depositosAcumulados[msg.sender];
        
        // MEJORA Calculo optimizado de comisión
        uint256 montoNeto = (montoADevolver * COMISION_FACTOR) / VALOR_CIEN;
        uint256 comision = montoADevolver - montoNeto;

        // Resetear antes de enviar
        depositosAcumulados[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: montoNeto, gas: 30000}("");
        require(success, "Error al enviar reembolso");
        
        (bool successComision, ) = payable(propietario).call{value: comision}("");	
        require(successComision, "Error al enviar comision");
        
        emit DevolverDeposito(msg.sender, montoNeto, comision);
    }
    
    // MEJORA reembolsoParcial() Eliminar For - Optimizar uso Gas
    function reembolsoParcial() external soloActiva {
        require(depositosAcumulados[msg.sender] > 0, "No tienes depositos para retirar");
        require(msg.sender != mejorOfertante, "El mejor ofertante no puede solicitar reembolso parcial");
        
        // MEJORA Usar mapping en lugar de loop 
        uint256 ultimaOfertaPersonal = ultimaOfertaPorUsuario[msg.sender];
        require(ultimaOfertaPersonal > 0, "No tienes una oferta registrada");
        
        uint256 depositoTotal = depositosAcumulados[msg.sender];
        uint256 excesoDisponible = depositoTotal - ultimaOfertaPersonal;
        require(excesoDisponible > 0, "No tienes exceso para retirar");
        
        // Actualizar deposito
        depositosAcumulados[msg.sender] = ultimaOfertaPersonal;
        
        // Sin comisión en reembolso parcial
        (bool success, ) = payable(msg.sender).call{value: excesoDisponible}("");
        require(success, "Error al enviar reembolso parcial");
        
        // Devolver Deposito
        emit DevolverDeposito(msg.sender, excesoDisponible, 0);
    }

    function retirarGanancias() external soloPropietario soloFinalizada {
        require(estado == EstadoSubasta.FINALIZADA, "Debe finalizar la subasta primero");
        require(mejorOfertante != address(0), "No hay ganador");
        require(!gananciasRetiradas, "Las ganancias ya fueron retiradas");

        
        uint256 ganancias = montoGanadorFinal;
        gananciasRetiradas = true;
        
        (bool success, ) = payable(propietario).call{value: ganancias, gas: 30000}("");
        require(success, "Error al transferir ganancias");
    }
    
    // ===== FUNCIONES DE CONSULTA  =====
    
    function informacionSubasta() external view returns (
        string memory descripcion,
        uint256 tiempoRestante,
        uint256 mejorOfertaActual,
        address mejorOfertanteActual,
        bool activa,
        uint256 totalOfertas,
        uint256 totalParticipantes
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
            estado == EstadoSubasta.ACTIVA && block.timestamp < tiempoFinalizacion,
            ofertas.length,
            participantesActuales
        );
    }
    
    // Consultar Deposito x address
    function consultarDeposito(address ofertante) external view returns (uint256) {
        return depositosAcumulados[ofertante];
    }
    
    // Consultar Ultima oferta de un usuario
    function consultarUltimaOferta(address ofertante) external view returns (uint256) {
        return ultimaOfertaPorUsuario[ofertante];
    }
    
    // Mejora Calculo optimizado del monto mínimo
    function montoMinimoParaSuperar() external view returns (uint256) {
        if (mejorOferta == 0) {
            return 1;
        }
        return (mejorOferta * INCREMENTO_FACTOR) / VALOR_CIEN;
    }
    
    // NUEVA: Estado actual del contrato
    function estadoActual() external view returns (string memory) {
        if (estado == EstadoSubasta.ACTIVA) return "ACTIVA";
        if (estado == EstadoSubasta.FINALIZADA) return "FINALIZADA";
        return "CANCELADA";
    }
    
    // NUEVA: Verifica si las ganancias ya fueron retiradas
    function consultarGanancias() external view returns (
        uint256 montoGanador,
        bool yaRetiradas,
        address ganador
    ) {
        return (montoGanadorFinal, gananciasRetiradas, mejorOfertante);
    }

    // NUEVA: Consultar Metricas
    function consultarMetricas() external view returns (
        uint256 maxParticipantes,
        uint256 participantesActuales_,
        uint256 maxOfertasConsulta
    ) {
        return (MAX_PARTICIPANTES, participantesActuales, MAX_OFERTAS_CONSULTA);
    }
	
	// ==== MANEJO DE TRANSFERENCIAS NO DESEADAS ====
	receive() external payable {
	revert("No se aceptan transferencias directas. Use opcion oferta()");
	}

	fallback() external payable {
	revert("Funcion fallback realizada - Accion no definida");
	}
}