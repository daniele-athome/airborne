/// GENERATED CODE - DO NOT MODIFY BY HAND

/// ***************************************************************************
/// *                            pubspec_generator                            * 
/// ***************************************************************************

/*
  
  MIT License
  
  Copyright (c) 2021 Plague Fox
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
   
 */

// The pubspec file:
// https://dart.dev/tools/pub/pubspec

// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: unnecessary_raw_strings
// ignore_for_file: use_raw_strings
// ignore_for_file: avoid_escaping_inner_quotes
// ignore_for_file: prefer_single_quotes

/// Current app version
const String version = r'0.0.6+7';

/// The major version number: "1" in "1.2.3".
const int major = 0;

/// The minor version number: "2" in "1.2.3".
const int minor = 0;

/// The patch version number: "3" in "1.2.3".
const int patch = 6;

/// The pre-release identifier: "foo" in "1.2.3-foo".
const List<String> pre = <String>[];

/// The build identifier: "foo" in "1.2.3+foo".
const List<String> build = <String>[r'7'];

/// Build date in Unix Time (in seconds)
const int timestamp = 1631198079;

/// Name [name]
const String name = r'airborne';

/// Description [description]
const String description = r'Minimal aircraft management app for small groups';

/// Repository [repository]
const String repository = r'https://github.com/daniele-athome/airborne.git';

/// Issue tracker [issue_tracker]
const String issueTracker = r'https://github.com/daniele-athome/airborne/issues';

/// Homepage [homepage]
const String homepage = r'https://github.com/daniele-athome/airborne';

/// Documentation [documentation]
const String documentation = r'';

/// Publish to [publish_to]
const String publishTo = r'none';

/// Environment
const Map<String, String> environment = <String, String>{
  'sdk': '>=2.12.0 <3.0.0',
};

/// Dependencies
const Map<String, Object> dependencies = <String, Object>{
  'archive': r'3.1.2',
  'cupertino_icons': r'1.0.3',
  'flutter': <String, Object>{
    'sdk': r'flutter',
  },
  'flutter_localizations': <String, Object>{
    'sdk': r'flutter',
  },
  'flutter_platform_widgets': r'1.9.5',
  'fluttertoast': r'8.0.8',
  'googleapis': r'4.0.0',
  'googleapis_auth': r'1.1.0',
  'intl': r'0.17.0',
  'logging': r'1.0.1',
  'material_segmented_control': r'3.1.2',
  'package_info_plus': r'1.0.6',
  'path': r'1.8.0',
  'path_provider': r'2.0.3',
  'provider': r'6.0.0',
  'shared_preferences': r'2.0.7',
  'solar_calculator': r'1.0.2',
  'syncfusion_flutter_calendar': r'19.2.60',
  'syncfusion_localizations': r'19.2.60',
  'timezone': r'0.7.0',
  'validators': r'3.0.0',
};

/// Developer dependencies
const Map<String, Object> devDependencies = <String, Object>{
  'flutter_driver': <String, Object>{
    'sdk': r'flutter',
  },
  'flutter_test': <String, Object>{
    'sdk': r'flutter',
  },
  'lint': r'any',
  'mockito': r'any',
  'screenshots': <String, Object>{
    'git': <String, Object>{
      'url': r'https://github.com/xal/screenshots',
    },
  },
  'test': r'any',
};

/// Dependency overrides
const Map<String, Object> dependencyOverrides = <String, Object>{};

/// Executables
const Map<String, Object> executables = <String, Object>{};

/// Source data from pubspec.yaml
const Map<String, Object> source = <String, Object>{
  'name': name,
  'description': description,
  'repository': repository,
  'issue_tracker': issueTracker,
  'homepage': homepage,
  'documentation': documentation,
  'publish_to': publishTo,
  'version': version,
  'environment': environment,
  'dependencies': dependencies,
  'dev_dependencies': devDependencies,
  'dependency_overrides': dependencyOverrides,
  'flutter': <String, Object>{
    'uses-material-design': true,
    'generate': true,
    'assets': <Object>[
      r'assets/images/',
    ],
  },
};
