// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

class CurrencyModel {
  DateTime? createdAt;
  String? symbol;
  String? code;
  bool? active;
  bool? symbolAtRight;
  String? name;
  int? decimalDigits;
  String? id;

  CurrencyModel({this.createdAt, this.symbol, this.code, this.active, this.symbolAtRight, this.name, this.decimalDigits, this.id});

  CurrencyModel.fromJson(Map<String, dynamic> json) {
    // createdAt = json['createdAt'];
     // Fix for Firestore timestamp
    if (json['createdAt'] != null) {
      var ts = json['createdAt'];
      if (ts is Timestamp) {
        createdAt = ts.toDate();
      } else if (ts is Map) {
        // Sometimes Firestore returns Map for nested data
        createdAt = DateTime.tryParse(ts['seconds'].toString());
      }
    }
    symbol = json['symbol'];
    code = json['code'];
    active = json['active'];
    symbolAtRight = json['symbolAtRight'];
    name = json['name'];
    decimalDigits = json['decimalDigits'] != null ? int.parse(json['decimalDigits'].toString()) : 2;
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createdAt'] = createdAt;
    data['symbol'] = symbol;
    data['code'] = code;
    data['active'] = active;
    data['symbolAtRight'] = symbolAtRight;
    data['name'] = name;
    data['decimalDigits'] = decimalDigits;
    data['id'] = id;
    return data;
  }
}
