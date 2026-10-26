{
  "version": "1.2",
  "package": {
    "name": "",
    "version": "",
    "description": "",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "alhambra-ii",
    "graph": {
      "blocks": [
        {
          "id": "6a206a8e-4575-46dc-b16a-265598087959",
          "type": "basic.output",
          "data": {
            "name": "led",
            "virtual": true,
            "pins": [
              {
                "index": "0",
                "name": "LED0",
                "value": "45"
              }
            ]
          },
          "position": {
            "x": 528,
            "y": 232
          }
        },
        {
          "id": "52ef2bdb-ebc8-4f17-ad01-027fde37055d",
          "type": "basic.input",
          "data": {
            "name": "clk",
            "virtual": true,
            "pins": [
              {
                "index": "0",
                "name": "CLK",
                "value": "49"
              }
            ],
            "clock": false,
            "isParametric": false
          },
          "position": {
            "x": 56,
            "y": 232
          }
        },
        {
          "id": "a1d63a64-2e20-44ff-8a48-9835681a1c41",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                }
              ],
              "out": [
                {
                  "name": "led"
                }
              ]
            },
            "params": [],
            "code": "   reg [23:0] contador = 0;\r\n   always @(posedge clk)\r\n     contador <= contador + 1;\r\n   assign led = contador[23];"
          },
          "position": {
            "x": 240,
            "y": 200
          },
          "size": {
            "width": 192,
            "height": 128
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "52ef2bdb-ebc8-4f17-ad01-027fde37055d",
            "port": "out"
          },
          "target": {
            "block": "a1d63a64-2e20-44ff-8a48-9835681a1c41",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "a1d63a64-2e20-44ff-8a48-9835681a1c41",
            "port": "led"
          },
          "target": {
            "block": "6a206a8e-4575-46dc-b16a-265598087959",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {},
  "settings": {
    "version": 1,
    "tools": {
      "verify": {
        "override": false,
        "relaxRealToInt": false,
        "relaxIoPrimitives": false,
        "allowLogicLoops": false,
        "verilatorFlags": ""
      },
      "build": {
        "override": false,
        "yosysFlags": "",
        "nextpnrFlags": ""
      },
      "upload": {
        "override": false
      }
    }
  }
}