// Modelo de simulacion de la planta de la demo (reunion del 17.11): un motor DC cuya velocidad
// depende del voltaje que le llega, con su sensor de velocidad. Lo usan tb_pid.v y tb_paso9.v.
//
//   DAC (0..3.3 V) -> etapa de op-amps (0..3.3 V -> -5..+5 V) -> driver -> motor -> sensor -> AD7606
//
// Lo que asume el modelo (cambiarlo cuando se conozca el motor real):
//   - Motor de 1er orden: TAU * d(rpm)/dt = K_MOTOR * CARGA * v_efectivo - rpm.
//     TAU = constante de tiempo mecanica; K_MOTOR = rpm por voltio en regimen; CARGA (0..1) baja
//     la velocidad como lo haria una carga en el eje (para probar perturbaciones).
//   - Zona muerta: por debajo de ZONA_MUERTA voltios el motor no arranca (friccion).
//   - Etapa de salida: 1.65 V del DAC = 0 V en el motor, ganancia 5 / 1.65 (lo que dice el documento
//     del equipo: "de 0-3.3 V a +-5 V"). Si Persona 1 la hace distinta, cambiar v_motor aqui.
//   - Sensor lineal: v_sensor = rpm * K_SENSOR, leido por el AD7606 en +-V_RANGO_ADC.
// Con los valores por defecto la ganancia de la planta es 1 en unidades de la cadena (+5 V al motor
// -> 3000 rpm -> +5 V del sensor): un cambio de 100 en la salida del PID mueve la medida 100.
`timescale 1ns/1ps
module motor_dc_modelo #(
    parameter real TAU         = 0.05,        // s
    parameter real K_MOTOR     = 600.0,       // rpm por voltio
    parameter real K_SENSOR    = 1.0 / 600.0, // voltios por rpm
    parameter real ZONA_MUERTA = 0.3,         // V
    parameter real V_RANGO_ADC = 5.0,         // +-5 V (pin RANGE del AD7606 en bajo)
    parameter real DT          = 100e-6       // s que avanza el modelo con cada pulso de 'paso'
) (
    input  wire        paso,                  // flanco de subida: avanza DT
    input  wire [11:0] codigo_dac,            // lo que saca el DAC (0..4095 = 0..3.3 V)
    output reg  [15:0] codigo_adc = 16'd0     // lo que lee el AD7606 del sensor (16 bits con signo)
);
    real carga    = 1.0;                      // el testbench la puede cambiar: motor.carga = 0.7;
    real rpm      = 0.0;
    real v_dac    = 0.0, v_motor = 0.0, v_ef = 0.0, v_sensor = 0.0, cuenta = 0.0;

    always @(posedge paso) begin
        v_dac   = codigo_dac * 3.3 / 4096.0;
        v_motor = (v_dac - 1.65) * (5.0 / 1.65);
        if      (v_motor >  ZONA_MUERTA) v_ef = v_motor - ZONA_MUERTA;
        else if (v_motor < -ZONA_MUERTA) v_ef = v_motor + ZONA_MUERTA;
        else                             v_ef = 0.0;
        rpm      = rpm + (K_MOTOR * carga * v_ef - rpm) * DT / TAU;
        v_sensor = rpm * K_SENSOR;
        cuenta   = v_sensor / V_RANGO_ADC * 32768.0;
        if      (cuenta >  32767.0) codigo_adc = 16'h7FFF;
        else if (cuenta < -32768.0) codigo_adc = 16'h8000;
        else                        codigo_adc = $rtoi(cuenta);    // trunca hacia 0, como un ADC real (+-1 LSB)
    end
endmodule
