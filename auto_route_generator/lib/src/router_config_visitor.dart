import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:auto_route_generator/route_config_visitor.dart';
import 'package:auto_route_generator/utils.dart';

const _validRouteAnnotations = [
  'MaterialRoute',
  'CupertinoRoute',
  'CustomRoute'
];

// extracts route configs from class fields
class RouterConfigVisitor extends SimpleElementVisitor {
  final routeConfigs = List<RouteConfig>();

  RouterConfigVisitor();

  @override
  RouteConfig visitFieldElement(FieldElement field) {
    final type = field.type;
    if (type.element is! ClassElement) {
      return null;
    }

    final routeConfig = RouteConfig();
    _extractMetaData(field, routeConfig);

    final import = getImport(type.element);

    if (import != null) {
      routeConfig.import = import;
    }
    routeConfig.name = field.name;
    routeConfig.className = type.name;

    final classElement = type.element as ClassElement;
    routeConfig.hasWrapper = classElement.allSupertypes
        .map<String>((el) => el.name)
        .contains('AutoRouteWrapper');
    final constructor = (type.element as ClassElement).unnamedConstructor;
    if (constructor != null && constructor.parameters.isNotEmpty) {
      routeConfig.parameters = constructor.parameters
          .map((p) => RouteParameter.fromParameterElement(p))
          .toList();
    }

    routeConfigs.add(routeConfig);
    return routeConfig;
  }

  void _extractMetaData(FieldElement field, RouteConfig routeConfig) {
    if (field.metadata != null && field.metadata.isNotEmpty) {
      final autoRoute = field.metadata.first.computeConstantValue();

      final type = autoRoute.type.toString();
      // only continue if annotation is MaterialRoute, Initial CupertinoRoute or CustomRoute.
      if (!_validRouteAnnotations.contains(type)) {
        return;
      }
      routeConfig.fullscreenDialog =
          autoRoute.getField('fullscreenDialog')?.toBoolValue();
      routeConfig.maintainState =
          autoRoute.getField('maintainState')?.toBoolValue();
      routeConfig.initial = autoRoute.getField('initial')?.toBoolValue();
      routeConfig.pathName = autoRoute.getField('name')?.toStringValue();
      if (type == 'CupertinoRoute') {
        routeConfig.routeType = RouteType.cupertino;
        routeConfig.cupertinoNavTitle =
            autoRoute.getField('title')?.toStringValue();
      } else if (type == 'CustomRoute') {
        routeConfig.routeType = RouteType.custom;
        routeConfig.durationInMilliseconds =
            autoRoute.getField('durationInMilliseconds').toIntValue();
        routeConfig.customRouteOpaque =
            autoRoute.getField('opaque')?.toBoolValue();
        routeConfig.customRouteBarrierDismissible =
            autoRoute.getField('barrierDismissible')?.toBoolValue();
        final function =
            autoRoute.getField('transitionsBuilder')?.toFunctionValue();
        if (function != null) {
          final import = getImport(function);
          final displayName =
              function.displayName.replaceFirst(RegExp('^_'), '');
          final functionName = (function.isStatic &&
                  function.enclosingElement?.displayName != null)
              ? '${function.enclosingElement.displayName}.$displayName'
              : displayName;
          routeConfig.transitionBuilder =
              CustomTransitionBuilder(functionName, import);
        }
      }
    }
  }
}
