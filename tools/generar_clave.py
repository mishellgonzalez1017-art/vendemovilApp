#!/usr/bin/env python3
"""Generador de claves de licencia (alternativa en Python, solo librería estándar).

Produce las mismas claves que tools/generar_clave.dart.

  LICENSE_SECRET="tu-secreto" python3 tools/generar_clave.py --dias 30
  LICENSE_SECRET="tu-secreto" python3 tools/generar_clave.py --hasta 2026-11-05
"""
import argparse
import datetime
import hashlib
import hmac
import os
import sys

ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def firma(fecha_aammdd: str, secreto: str) -> str:
    mac = hmac.new(secreto.encode("utf-8"), f"VM1|{fecha_aammdd}".encode("utf-8"), hashlib.sha256).digest()
    valor = int.from_bytes(mac[:5], "big")  # 40 bits -> 8 caracteres de 5 bits
    return "".join(ALFABETO[(valor >> (35 - 5 * i)) & 31] for i in range(8))


def generar(vence: datetime.date, secreto: str) -> str:
    fecha = vence.strftime("%y%m%d")
    return f"VM-{fecha}-{firma(fecha, secreto)}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dias", type=int, default=30, help="días desde hoy (por defecto 30)")
    g.add_argument("--hasta", help="fecha AAAA-MM-DD")
    args = ap.parse_args()

    secreto = os.environ.get("LICENSE_SECRET", "")
    if not secreto:
        print("Falta la variable de entorno LICENSE_SECRET.", file=sys.stderr)
        return 64

    if args.hasta:
        vence = datetime.date.fromisoformat(args.hasta)
    else:
        if args.dias < 1:
            print("--dias debe ser mayor que 0.", file=sys.stderr)
            return 64
        vence = datetime.date.today() + datetime.timedelta(days=args.dias)

    print(f"\nClave:  {generar(vence, secreto)}")
    print(f"Vale hasta el final del día {vence.isoformat()}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
