// signalgenerator: generador de senales del profesor (proyecto Vivado_Artix7_2025_06_24,
// signalgenerator_2.v), corregido y adaptado al reloj unico de 12 MHz del proyecto.
// Lo usa sig_gen.v (bloque "signal" de la cadena), que lo pasa al formato de 10 bits.
// Formato Q2.16 con signo (65536 = 1.0), igual que en el original.
//   signal_type: 0 cuadrada, 1 triangulo, 2 diente de sierra, 3 coseno, 4 seno, 5 ruido uniforme
//   frecuencia  = increment_per_cycle x f_ce / 2^24   (f_ce = 12 MHz con clock_enable = 1)
//   signal_out  = offset + (forma - 0.5) x signal_scale, con la forma entre 0 y 1.0
//
// Cambios respecto al original (marcados CORREGIDO (Gn) o ADAPTADO en el codigo). Los errores se
// comprobaron simulando el original sin cambios:
//   (G1) La interpolacion no funcionaba: el seno salia en escalones, uno por punto de la tabla
//        (medido con N = 10000: saltos de hasta 810 de 65536 entre un ciclo y el siguiente; el
//        corregido salta como maximo 21). Causas:
//        - diff * phase_accumulator[15:0] mezcla con signo y sin signo: Verilog hace entonces toda
//          la cuenta sin signo y con el ancho de signal_value (18 bits), y el termino de
//          interpolacion queda entre 0 y 3. Ahora la fraccion va con $signed y la cuenta es de 36 bits.
//        - cos_0, cos_1, sin_0, sin_1 y diff eran de 16 bits y la tabla de 18: el 1.0 (65536) se
//          leia como 0 (el original lo tapaba con un caso especial). Ahora son de 19 bits.
//        - el pipeline mezclaba tres muestras distintas (index_1 salia del index_0 viejo, diff de
//          los valores viejos y la fraccion de la fase nueva). Ahora viajan juntos.
//   (G2) La forma dependia de dos ajustes que tenian que coincidir (clkcycles_per_period y el
//        incremento). Con los valores del propio proyecto (N = 10000) la sierra llegaba a +37232 en
//        vez de +32768 y el triangulo solo a +32245; ademas la tabla tenia 255 pasos por vuelta y
//        el indice de 8 bits da la vuelta a los 256. Ahora la tabla tiene 256 pasos y todas las
//        formas salen de la misma fase: la frecuencia la fija solo increment_per_cycle (se quito
//        clkcycles_per_period). El coseno usa la misma tabla corrida 90 grados (antes, dos tablas).
//   (G3) offset + senal podia pasar de +-2.0 y daba la vuelta (de +2 a -2). Ahora se satura.
//   (G4) urandgenerator no tenia valor inicial: sin pulso de reset el LFSR se queda en 0 para
//        siempre (ruido plano). Ver urandgenerator.v.
//   ADAPTADO: reset sincrono (en este proyecto no hay reset global; el top lo deja en 0).
module signalgenerator (
    input  wire               clock_enable,
    input  wire        [2:0]  signal_type,
    input  wire signed [17:0] offset,
    input  wire               rst,
    input  wire               clk,
    input  wire        [17:0] increment_per_cycle,
    input  wire signed [17:0] signal_scale,
    output wire signed [17:0] signal_out
);
    reg        [23:0] phase_accumulator = 24'd0;

    // pipeline: fase -> indices -> tabla -> forma -> escala -> salida
    reg        [7:0]  index_0 = 0, index_1 = 0;            // CORREGIDO (G1): salen de la misma fase
    reg        [15:0] frac_1 = 0, frac_2 = 0;
    reg        [23:0] phase_1 = 0, phase_2 = 0;
    reg        [2:0]  type_1 = 0, type_2 = 0;
    reg signed [18:0] tab_0 = 0, tab_1 = 0;                // CORREGIDO (G1): 18 bits + signo
    wire signed [18:0] diff = tab_1 - tab_0;               // CORREGIDO (G1)
    wire signed [35:0] interp_mult = diff * $signed({1'b0, frac_2});   // CORREGIDO (G1)
    wire signed [18:0] interp = tab_0 + (interp_mult >>> 16);
    reg signed [18:0] signal_value = 0;                    // forma elegida: 0 .. 1.0
    reg signed [18:0] signal_value_pipe = 0;               // forma - 0.5: -0.5 .. +0.5
    reg signed [36:0] signal_scaled_reg = 0;
    reg signed [20:0] scaled_result = 0;
    reg signed [17:0] signal_out_reg = 0;
    wire signed [21:0] suma = offset + scaled_result;      // CORREGIDO (G3): sin vuelta
    wire signed [17:0] urand;

    // CORREGIDO (G2): 256 puntos por vuelta, valor = 0.5 + 0.5 sin(2 pi i / 256), en Q2.16
    reg        [17:0] sin_table [0:255];
    initial begin
        sin_table[  0] = 18'd32768;  // 0.50000
        sin_table[  1] = 18'd33572;  // 0.51227
        sin_table[  2] = 18'd34376;  // 0.52454
        sin_table[  3] = 18'd35179;  // 0.53679
        sin_table[  4] = 18'd35980;  // 0.54901
        sin_table[  5] = 18'd36779;  // 0.56120
        sin_table[  6] = 18'd37576;  // 0.57336
        sin_table[  7] = 18'd38370;  // 0.58548
        sin_table[  8] = 18'd39161;  // 0.59755
        sin_table[  9] = 18'd39948;  // 0.60956
        sin_table[ 10] = 18'd40730;  // 0.62149
        sin_table[ 11] = 18'd41508;  // 0.63336
        sin_table[ 12] = 18'd42280;  // 0.64514
        sin_table[ 13] = 18'd43047;  // 0.65685
        sin_table[ 14] = 18'd43807;  // 0.66844
        sin_table[ 15] = 18'd44561;  // 0.67995
        sin_table[ 16] = 18'd45308;  // 0.69135
        sin_table[ 17] = 18'd46047;  // 0.70262
        sin_table[ 18] = 18'd46778;  // 0.71378
        sin_table[ 19] = 18'd47501;  // 0.72481
        sin_table[ 20] = 18'd48215;  // 0.73570
        sin_table[ 21] = 18'd48919;  // 0.74644
        sin_table[ 22] = 18'd49614;  // 0.75705
        sin_table[ 23] = 18'd50299;  // 0.76750
        sin_table[ 24] = 18'd50973;  // 0.77779
        sin_table[ 25] = 18'd51636;  // 0.78790
        sin_table[ 26] = 18'd52288;  // 0.79785
        sin_table[ 27] = 18'd52928;  // 0.80762
        sin_table[ 28] = 18'd53556;  // 0.81720
        sin_table[ 29] = 18'd54171;  // 0.82658
        sin_table[ 30] = 18'd54774;  // 0.83578
        sin_table[ 31] = 18'd55363;  // 0.84477
        sin_table[ 32] = 18'd55938;  // 0.85355
        sin_table[ 33] = 18'd56500;  // 0.86212
        sin_table[ 34] = 18'd57047;  // 0.87047
        sin_table[ 35] = 18'd57580;  // 0.87860
        sin_table[ 36] = 18'd58098;  // 0.88651
        sin_table[ 37] = 18'd58601;  // 0.89418
        sin_table[ 38] = 18'd59088;  // 0.90161
        sin_table[ 39] = 18'd59559;  // 0.90880
        sin_table[ 40] = 18'd60014;  // 0.91574
        sin_table[ 41] = 18'd60452;  // 0.92242
        sin_table[ 42] = 18'd60874;  // 0.92886
        sin_table[ 43] = 18'd61279;  // 0.93504
        sin_table[ 44] = 18'd61667;  // 0.94096
        sin_table[ 45] = 18'd62037;  // 0.94661
        sin_table[ 46] = 18'd62390;  // 0.95200
        sin_table[ 47] = 18'd62725;  // 0.95711
        sin_table[ 48] = 18'd63042;  // 0.96194
        sin_table[ 49] = 18'd63340;  // 0.96649
        sin_table[ 50] = 18'd63621;  // 0.97078
        sin_table[ 51] = 18'd63882;  // 0.97476
        sin_table[ 52] = 18'd64125;  // 0.97847
        sin_table[ 53] = 18'd64349;  // 0.98189
        sin_table[ 54] = 18'd64554;  // 0.98502
        sin_table[ 55] = 18'd64740;  // 0.98785
        sin_table[ 56] = 18'd64906;  // 0.99039
        sin_table[ 57] = 18'd65054;  // 0.99265
        sin_table[ 58] = 18'd65181;  // 0.99458
        sin_table[ 59] = 18'd65290;  // 0.99625
        sin_table[ 60] = 18'd65378;  // 0.99759
        sin_table[ 61] = 18'd65447;  // 0.99864
        sin_table[ 62] = 18'd65497;  // 0.99940
        sin_table[ 63] = 18'd65526;  // 0.99985
        sin_table[ 64] = 18'd65536;  // 1.00000
        sin_table[ 65] = 18'd65526;  // 0.99985
        sin_table[ 66] = 18'd65497;  // 0.99940
        sin_table[ 67] = 18'd65447;  // 0.99864
        sin_table[ 68] = 18'd65378;  // 0.99759
        sin_table[ 69] = 18'd65290;  // 0.99625
        sin_table[ 70] = 18'd65181;  // 0.99458
        sin_table[ 71] = 18'd65054;  // 0.99265
        sin_table[ 72] = 18'd64906;  // 0.99039
        sin_table[ 73] = 18'd64740;  // 0.98785
        sin_table[ 74] = 18'd64554;  // 0.98502
        sin_table[ 75] = 18'd64349;  // 0.98189
        sin_table[ 76] = 18'd64125;  // 0.97847
        sin_table[ 77] = 18'd63882;  // 0.97476
        sin_table[ 78] = 18'd63621;  // 0.97078
        sin_table[ 79] = 18'd63340;  // 0.96649
        sin_table[ 80] = 18'd63042;  // 0.96194
        sin_table[ 81] = 18'd62725;  // 0.95711
        sin_table[ 82] = 18'd62390;  // 0.95200
        sin_table[ 83] = 18'd62037;  // 0.94661
        sin_table[ 84] = 18'd61667;  // 0.94096
        sin_table[ 85] = 18'd61279;  // 0.93504
        sin_table[ 86] = 18'd60874;  // 0.92886
        sin_table[ 87] = 18'd60452;  // 0.92242
        sin_table[ 88] = 18'd60014;  // 0.91574
        sin_table[ 89] = 18'd59559;  // 0.90880
        sin_table[ 90] = 18'd59088;  // 0.90161
        sin_table[ 91] = 18'd58601;  // 0.89418
        sin_table[ 92] = 18'd58098;  // 0.88651
        sin_table[ 93] = 18'd57580;  // 0.87860
        sin_table[ 94] = 18'd57047;  // 0.87047
        sin_table[ 95] = 18'd56500;  // 0.86212
        sin_table[ 96] = 18'd55938;  // 0.85355
        sin_table[ 97] = 18'd55363;  // 0.84477
        sin_table[ 98] = 18'd54774;  // 0.83578
        sin_table[ 99] = 18'd54171;  // 0.82658
        sin_table[100] = 18'd53556;  // 0.81720
        sin_table[101] = 18'd52928;  // 0.80762
        sin_table[102] = 18'd52288;  // 0.79785
        sin_table[103] = 18'd51636;  // 0.78790
        sin_table[104] = 18'd50973;  // 0.77779
        sin_table[105] = 18'd50299;  // 0.76750
        sin_table[106] = 18'd49614;  // 0.75705
        sin_table[107] = 18'd48919;  // 0.74644
        sin_table[108] = 18'd48215;  // 0.73570
        sin_table[109] = 18'd47501;  // 0.72481
        sin_table[110] = 18'd46778;  // 0.71378
        sin_table[111] = 18'd46047;  // 0.70262
        sin_table[112] = 18'd45308;  // 0.69135
        sin_table[113] = 18'd44561;  // 0.67995
        sin_table[114] = 18'd43807;  // 0.66844
        sin_table[115] = 18'd43047;  // 0.65685
        sin_table[116] = 18'd42280;  // 0.64514
        sin_table[117] = 18'd41508;  // 0.63336
        sin_table[118] = 18'd40730;  // 0.62149
        sin_table[119] = 18'd39948;  // 0.60956
        sin_table[120] = 18'd39161;  // 0.59755
        sin_table[121] = 18'd38370;  // 0.58548
        sin_table[122] = 18'd37576;  // 0.57336
        sin_table[123] = 18'd36779;  // 0.56120
        sin_table[124] = 18'd35980;  // 0.54901
        sin_table[125] = 18'd35179;  // 0.53679
        sin_table[126] = 18'd34376;  // 0.52454
        sin_table[127] = 18'd33572;  // 0.51227
        sin_table[128] = 18'd32768;  // 0.50000
        sin_table[129] = 18'd31964;  // 0.48773
        sin_table[130] = 18'd31160;  // 0.47546
        sin_table[131] = 18'd30357;  // 0.46321
        sin_table[132] = 18'd29556;  // 0.45099
        sin_table[133] = 18'd28757;  // 0.43880
        sin_table[134] = 18'd27960;  // 0.42664
        sin_table[135] = 18'd27166;  // 0.41452
        sin_table[136] = 18'd26375;  // 0.40245
        sin_table[137] = 18'd25588;  // 0.39044
        sin_table[138] = 18'd24806;  // 0.37851
        sin_table[139] = 18'd24028;  // 0.36664
        sin_table[140] = 18'd23256;  // 0.35486
        sin_table[141] = 18'd22489;  // 0.34315
        sin_table[142] = 18'd21729;  // 0.33156
        sin_table[143] = 18'd20975;  // 0.32005
        sin_table[144] = 18'd20228;  // 0.30865
        sin_table[145] = 18'd19489;  // 0.29738
        sin_table[146] = 18'd18758;  // 0.28622
        sin_table[147] = 18'd18035;  // 0.27519
        sin_table[148] = 18'd17321;  // 0.26430
        sin_table[149] = 18'd16617;  // 0.25356
        sin_table[150] = 18'd15922;  // 0.24295
        sin_table[151] = 18'd15237;  // 0.23250
        sin_table[152] = 18'd14563;  // 0.22221
        sin_table[153] = 18'd13900;  // 0.21210
        sin_table[154] = 18'd13248;  // 0.20215
        sin_table[155] = 18'd12608;  // 0.19238
        sin_table[156] = 18'd11980;  // 0.18280
        sin_table[157] = 18'd11365;  // 0.17342
        sin_table[158] = 18'd10762;  // 0.16422
        sin_table[159] = 18'd10173;  // 0.15523
        sin_table[160] = 18'd 9598;  // 0.14645
        sin_table[161] = 18'd 9036;  // 0.13788
        sin_table[162] = 18'd 8489;  // 0.12953
        sin_table[163] = 18'd 7956;  // 0.12140
        sin_table[164] = 18'd 7438;  // 0.11349
        sin_table[165] = 18'd 6935;  // 0.10582
        sin_table[166] = 18'd 6448;  // 0.09839
        sin_table[167] = 18'd 5977;  // 0.09120
        sin_table[168] = 18'd 5522;  // 0.08426
        sin_table[169] = 18'd 5084;  // 0.07758
        sin_table[170] = 18'd 4662;  // 0.07114
        sin_table[171] = 18'd 4257;  // 0.06496
        sin_table[172] = 18'd 3869;  // 0.05904
        sin_table[173] = 18'd 3499;  // 0.05339
        sin_table[174] = 18'd 3146;  // 0.04800
        sin_table[175] = 18'd 2811;  // 0.04289
        sin_table[176] = 18'd 2494;  // 0.03806
        sin_table[177] = 18'd 2196;  // 0.03351
        sin_table[178] = 18'd 1915;  // 0.02922
        sin_table[179] = 18'd 1654;  // 0.02524
        sin_table[180] = 18'd 1411;  // 0.02153
        sin_table[181] = 18'd 1187;  // 0.01811
        sin_table[182] = 18'd  982;  // 0.01498
        sin_table[183] = 18'd  796;  // 0.01215
        sin_table[184] = 18'd  630;  // 0.00961
        sin_table[185] = 18'd  482;  // 0.00735
        sin_table[186] = 18'd  355;  // 0.00542
        sin_table[187] = 18'd  246;  // 0.00375
        sin_table[188] = 18'd  158;  // 0.00241
        sin_table[189] = 18'd   89;  // 0.00136
        sin_table[190] = 18'd   39;  // 0.00060
        sin_table[191] = 18'd   10;  // 0.00015
        sin_table[192] = 18'd    0;  // 0.00000
        sin_table[193] = 18'd   10;  // 0.00015
        sin_table[194] = 18'd   39;  // 0.00060
        sin_table[195] = 18'd   89;  // 0.00136
        sin_table[196] = 18'd  158;  // 0.00241
        sin_table[197] = 18'd  246;  // 0.00375
        sin_table[198] = 18'd  355;  // 0.00542
        sin_table[199] = 18'd  482;  // 0.00735
        sin_table[200] = 18'd  630;  // 0.00961
        sin_table[201] = 18'd  796;  // 0.01215
        sin_table[202] = 18'd  982;  // 0.01498
        sin_table[203] = 18'd 1187;  // 0.01811
        sin_table[204] = 18'd 1411;  // 0.02153
        sin_table[205] = 18'd 1654;  // 0.02524
        sin_table[206] = 18'd 1915;  // 0.02922
        sin_table[207] = 18'd 2196;  // 0.03351
        sin_table[208] = 18'd 2494;  // 0.03806
        sin_table[209] = 18'd 2811;  // 0.04289
        sin_table[210] = 18'd 3146;  // 0.04800
        sin_table[211] = 18'd 3499;  // 0.05339
        sin_table[212] = 18'd 3869;  // 0.05904
        sin_table[213] = 18'd 4257;  // 0.06496
        sin_table[214] = 18'd 4662;  // 0.07114
        sin_table[215] = 18'd 5084;  // 0.07758
        sin_table[216] = 18'd 5522;  // 0.08426
        sin_table[217] = 18'd 5977;  // 0.09120
        sin_table[218] = 18'd 6448;  // 0.09839
        sin_table[219] = 18'd 6935;  // 0.10582
        sin_table[220] = 18'd 7438;  // 0.11349
        sin_table[221] = 18'd 7956;  // 0.12140
        sin_table[222] = 18'd 8489;  // 0.12953
        sin_table[223] = 18'd 9036;  // 0.13788
        sin_table[224] = 18'd 9598;  // 0.14645
        sin_table[225] = 18'd10173;  // 0.15523
        sin_table[226] = 18'd10762;  // 0.16422
        sin_table[227] = 18'd11365;  // 0.17342
        sin_table[228] = 18'd11980;  // 0.18280
        sin_table[229] = 18'd12608;  // 0.19238
        sin_table[230] = 18'd13248;  // 0.20215
        sin_table[231] = 18'd13900;  // 0.21210
        sin_table[232] = 18'd14563;  // 0.22221
        sin_table[233] = 18'd15237;  // 0.23250
        sin_table[234] = 18'd15922;  // 0.24295
        sin_table[235] = 18'd16617;  // 0.25356
        sin_table[236] = 18'd17321;  // 0.26430
        sin_table[237] = 18'd18035;  // 0.27519
        sin_table[238] = 18'd18758;  // 0.28622
        sin_table[239] = 18'd19489;  // 0.29738
        sin_table[240] = 18'd20228;  // 0.30865
        sin_table[241] = 18'd20975;  // 0.32005
        sin_table[242] = 18'd21729;  // 0.33156
        sin_table[243] = 18'd22489;  // 0.34315
        sin_table[244] = 18'd23256;  // 0.35486
        sin_table[245] = 18'd24028;  // 0.36664
        sin_table[246] = 18'd24806;  // 0.37851
        sin_table[247] = 18'd25588;  // 0.39044
        sin_table[248] = 18'd26375;  // 0.40245
        sin_table[249] = 18'd27166;  // 0.41452
        sin_table[250] = 18'd27960;  // 0.42664
        sin_table[251] = 18'd28757;  // 0.43880
        sin_table[252] = 18'd29556;  // 0.45099
        sin_table[253] = 18'd30357;  // 0.46321
        sin_table[254] = 18'd31160;  // 0.47546
        sin_table[255] = 18'd31964;  // 0.48773
    end

    urandgenerator noise_gen (
        .clk(clk),
        .ce(clock_enable),
        .rst(rst),
        .out(urand)
    );

    always @(posedge clk) begin
        if (rst) begin                                     // ADAPTADO: reset sincrono
            phase_accumulator <= 0;
            signal_value      <= 0;
            signal_value_pipe <= 0;
            signal_scaled_reg <= 0;
            scaled_result     <= 0;
            signal_out_reg    <= 0;
        end
        else if (clock_enable) begin
            phase_accumulator <= phase_accumulator + {6'b0, increment_per_cycle};

            // etapa 1: indices y fraccion de la misma fase; el coseno es el seno corrido 64 pasos
            index_0 <= phase_accumulator[23:16] + ((signal_type == 3'b011) ? 8'd64 : 8'd0);
            index_1 <= phase_accumulator[23:16] + ((signal_type == 3'b011) ? 8'd65 : 8'd1);
            frac_1  <= phase_accumulator[15:0];
            phase_1 <= phase_accumulator;
            type_1  <= signal_type;

            // etapa 2: los dos puntos de la tabla (el indice 255 + 1 da la vuelta a 0: es correcto)
            tab_0   <= $signed({1'b0, sin_table[index_0]});
            tab_1   <= $signed({1'b0, sin_table[index_1]});
            frac_2  <= frac_1;
            phase_2 <= phase_1;
            type_2  <= type_1;

            // etapa 3: la forma, entre 0 y 1.0 (65536)
            case (type_2)
                3'b000: signal_value <= phase_2[23] ? 19'sd65536 : 19'sd0;                  // cuadrada
                3'b001: signal_value <= phase_2[23] ? 19'sd131072 - $signed({2'b00, phase_2[23:8], 1'b0})
                                                    : $signed({2'b00, phase_2[22:8], 1'b0}); // triangulo
                3'b010: signal_value <= $signed({3'b000, phase_2[23:8]});                     // sierra
                3'b011,
                3'b100: signal_value <= interp;                                               // coseno, seno
                3'b101: signal_value <= urand;                                                // ruido
                default: signal_value <= 0;
            endcase

            // etapas 4 a 6: como en el original, -0.5, escala y offset
            signal_value_pipe <= signal_value - 19'sd32768;
            signal_scaled_reg <= signal_scale * signal_value_pipe;
            scaled_result     <= signal_scaled_reg >>> 16;   // ">>>" conserva el signo
            if      (suma >  22'sd131071) signal_out_reg <=  18'sd131071;   // CORREGIDO (G3)
            else if (suma < -22'sd131072) signal_out_reg <= -18'sd131072;
            else                          signal_out_reg <= suma[17:0];
        end
    end

    assign signal_out = signal_out_reg;
endmodule
