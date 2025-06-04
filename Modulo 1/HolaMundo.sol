// SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

contract HolaMundo{
    string public saludo;       // variable de guardado

    function verSaludo() view external returns (string memory) {
        return (saludo);
    }
    
    function setSaludo(string calldata _nuevoSaludo) external { 
        saludo = _nuevoSaludo;
    }
}