import std.stdio;
import std.file : getcwd, exists, isDir, mkdirRecurse, write, dirEntries, SpanMode;
import std.path : buildPath, dirName, baseName;
import std.array : array;
import std.format : format;
import std.ascii : toUpper;
import std.uni : toLower;
import std.string : split;
import std.range;
import std.algorithm;

/// Преобразует строку в PascalCase (например, "hello_world" -> "HelloWorld")
string toPascalCase(string s)
{
    // Разбиваем строку по символам '_' и пробелу
    auto parts = s.split!(c => c == '_' || c == ' ').array;
    string result;
    foreach (part; parts)
    {
        if (part.length > 0)
            result ~= toUpper(part[0]) ~ toLower(part[1 .. $]);
    }
    return result;
}

void main(string[] args)
{
    version(Windows)
    {
        import core.sys.windows.windows : SetConsoleOutputCP;
        // Устанавливаем кодовую страницу UTF-8 для вывода в консоль
        SetConsoleOutputCP(65001);
    }

    writeln("Запуск генератора модулей...");

    // Если параметры не заданы, выводим справку
    if (args.length < 2)
    {
        writeln("Usage: generator <module_name> [crud|empty]");
        return;
    }

    string moduleName = args[1];                  // Например, "hello"
    string ModuleName = toPascalCase(moduleName);   // Например, "Hello"
    writeln("Обработка модуля: ", moduleName, " (", ModuleName, ")");

    // Определяем тип шаблона (по умолчанию "crud")
    string templateType = (args.length > 2) ? args[2].toLower() : "crud";
    writeln("Тип шаблона: ", templateType);

    // Получаем текущую рабочую директорию
    string currentDir = getcwd();
    writeln("Текущая директория: ", currentDir);
    // Формируем путь до папки source
    string sourceDir = buildPath(currentDir, "source");
    if (!(exists(sourceDir) && isDir(sourceDir)))
    {
        mkdirRecurse(sourceDir);
        writeln("Создан каталог: ", sourceDir);
    }
    else
    {
        writeln("Каталог уже существует: ", sourceDir);
    }

    // Формируем путь до папки для модуля: source/<moduleName>
    string baseDir = buildPath(sourceDir, moduleName);
    if (!(exists(baseDir) && isDir(baseDir)))
    {
        mkdirRecurse(baseDir);
        writeln("Создан каталог для модуля: ", baseDir);
    }
    else
    {
        writeln("Каталог для модуля уже существует: ", baseDir);
    }

    // 1. Генерация файла контроллера: <moduleName>.controller.d
    string controllerFile = buildPath(baseDir, moduleName ~ ".controller.d");
    writeln("Генерация контроллера: ", controllerFile);
    string controllerContent;
    if (templateType == "crud")
    {
        // Шаблон с CRUD-методами (используем res.writeBody)
        string controllerTemplate = q{
module %s.%s.controller;

import vibe.vibe;
import %s.%s.service;

class %sController {
    private %sService %sService;

    this(%sService %sService) {
        this.%sService = %sService;
    }

    /// GET /%s
    void getAll(HTTPServerRequest req, HTTPServerResponse res) {
        res.headers["Content-Type"] = "application/json; charset=UTF-8";
        res.writeBody(%s.getAll());
    }

    /// GET /%s/:id
    void getOne(HTTPServerRequest req, HTTPServerResponse res) {
        res.headers["Content-Type"] = "application/json; charset=UTF-8";
        res.writeBody(%s.getOne());
    }

    /// POST /%s
    void create(HTTPServerRequest req, HTTPServerResponse res) {
        res.headers["Content-Type"] = "application/json; charset=UTF-8";
        res.writeBody(%s.create());
    }

    /// PUT /%s/:id
    void update(HTTPServerRequest req, HTTPServerResponse res) {
        res.headers["Content-Type"] = "application/json; charset=UTF-8";
        res.writeBody(%s.update());
    }

    /// DELETE /%s/:id
    void remove(HTTPServerRequest req, HTTPServerResponse res) {
        res.headers["Content-Type"] = "application/json; charset=UTF-8";
        res.writeBody(%s.remove());
    }
}
};
        controllerContent = format(
            controllerTemplate,
            moduleName, moduleName,                 // module и подпакет controller
            moduleName, moduleName,                 // импорт сервиса
            ModuleName, ModuleName, moduleName,       // имя класса, тип и имя поля сервиса
            ModuleName, moduleName,                 // параметры конструктора
            moduleName, moduleName,                 // присваивание в конструкторе
            moduleName,                           // маршрут для GET /<moduleName>
            moduleName ~ "Service",               // вызов метода getAll
            moduleName,                           // маршрут для GET /<moduleName>/:id
            moduleName ~ "Service",               // вызов метода getOne
            moduleName,                           // маршрут для POST /<moduleName>
            moduleName ~ "Service",               // вызов метода create
            moduleName,                           // маршрут для PUT /<moduleName>/:id
            moduleName ~ "Service",               // вызов метода update
            moduleName,                           // маршрут для DELETE /<moduleName>/:id
            moduleName ~ "Service"                // вызов метода remove
        );
    }
    else if (templateType == "empty")
    {
        // Пустой шаблон с комментариями и примером GET запроса
        string controllerTemplate = q{
module %s.%s.controller;

import vibe.vibe;

class %sController {
    // Пример GET запроса:
    // void getExample(HTTPServerRequest req, HTTPServerResponse res) {
    //     res.headers["Content-Type"] = "application/json; charset=UTF-8";
    //     res.writeBody("Hello from GET example");
    // }
}
};
        controllerContent = format(
            controllerTemplate,
            moduleName, moduleName,  // module и подпакет controller
            ModuleName               // имя класса контроллера
        );
    }
    else
    {
        writeln("Неизвестный тип шаблона: ", templateType);
        return;
    }
    write(controllerFile, controllerContent);
    writeln("Файл контроллера создан: ", controllerFile);

    // 2. Генерация файла сервиса: <moduleName>.service.d
    string serviceFile = buildPath(baseDir, moduleName ~ ".service.d");
    writeln("Генерация сервиса: ", serviceFile);
    string serviceContent;
    if (templateType == "crud")
    {
        string serviceTemplate = q{
module %s.%s.service;

class %sService {
    string getAll() {
        return "GET all %s";
    }

    string getOne() {
        return "GET one %s";
    }

    string create() {
        return "CREATE %s";
    }

    string update() {
        return "UPDATE %s";
    }

    string remove() {
        return "DELETE %s";
    }
}
};
        serviceContent = format(
            serviceTemplate,
            moduleName, moduleName,  // module и подпакет service
            ModuleName,              // имя класса сервиса
            moduleName,              // для getAll
            moduleName,              // для getOne
            moduleName,              // для create
            moduleName,              // для update
            moduleName               // для remove
        );
    }
    else if (templateType == "empty")
    {
        string serviceTemplate = q{
module %s.%s.service;

// Пустой сервис: добавьте здесь бизнес-логику
class %sService {
    // Пример метода:
    // string example() {
    //     return "Example response";
    // }
}
};
        serviceContent = format(
            serviceTemplate,
            moduleName, moduleName, // module и подпакет service
            ModuleName              // имя класса сервиса
        );
    }
    write(serviceFile, serviceContent);
    writeln("Файл сервиса создан: ", serviceFile);

    // 3. Генерация файла модуля: <moduleName>.mod.d (с суффиксом "mod" вместо "module")
    string moduleFile = buildPath(baseDir, moduleName ~ ".mod.d");
    writeln("Генерация модуля: ", moduleFile);
    string moduleContent;
    if (templateType == "crud")
    {
        string moduleTemplate = q{
module %s.%s.mod;

import vibe.vibe;
import %s.%s.controller;
import %s.%s.service;

class %sModule {
    private %sService %sService;
    private %sController %sController;

    this() {
        %sService = new %sService();
        %sController = new %sController(%sService);
    }

    /// Регистрирует маршруты для модуля %s с CRUD методами
    void registerRoutes(URLRouter router) {
        router.get("/%s", (HTTPServerRequest req, HTTPServerResponse res) {
            %s.getAll(req, res);
        });
        router.get("/%s/:id", (HTTPServerRequest req, HTTPServerResponse res) {
            %s.getOne(req, res);
        });
        router.post("/%s", (HTTPServerRequest req, HTTPServerResponse res) {
            %s.create(req, res);
        });
        router.put("/%s/:id", (HTTPServerRequest req, HTTPServerResponse res) {
            %s.update(req, res);
        });
        router.delete_("/%s/:id", (HTTPServerRequest req, HTTPServerResponse res) {
            %s.remove(req, res);
        });
    }
}
};
        moduleContent = format(
            moduleTemplate,
            moduleName, moduleName,        // module и подпакет mod
            moduleName, moduleName,        // импорт контроллера
            moduleName, moduleName,        // импорт сервиса
            ModuleName,                    // имя класса модуля
            ModuleName, moduleName,        // тип сервиса и имя поля
            ModuleName, moduleName,        // тип контроллера и имя поля
            moduleName, ModuleName,        // создание сервиса: поле и тип
            moduleName, ModuleName,        // создание контроллера: поле и тип
            moduleName,                    // передаём сервис в конструктор
            moduleName,                    // для комментария (имя модуля)
            moduleName,                    // маршрут для GET all
            moduleName ~ "Controller",     // вызов getAll
            moduleName,                    // маршрут для GET one
            moduleName ~ "Controller",     // вызов getOne
            moduleName,                    // маршрут для POST
            moduleName ~ "Controller",     // вызов create
            moduleName,                    // маршрут для PUT
            moduleName ~ "Controller",     // вызов update
            moduleName,                    // маршрут для DELETE
            moduleName ~ "Controller"      // вызов remove
        );
    }
    else if (templateType == "empty")
    {
        string moduleTemplate = q{
module %s.%s.mod;

import vibe.vibe;
import %s.%s.controller;
import %s.%s.service;

class %sModule {
    private %sService %sService;
    // Контроллер не создан, добавьте методы и регистрацию маршрутов по необходимости.
    // Пример регистрации:
    // void registerRoutes(URLRouter router) {
    //     // router.get("/example", (req, res) { ... });
    // }

    this() {
        %sService = new %sService();
    }
}
};
        moduleContent = format(
            moduleTemplate,
            moduleName, moduleName,  // module и подпакет mod
            moduleName, moduleName,  // импорт контроллера
            moduleName, moduleName,  // импорт сервиса
            ModuleName,              // имя класса модуля
            ModuleName, moduleName,  // тип сервиса и имя поля
            moduleName,              // создание сервиса
            moduleName, ModuleName   // имя класса сервиса
        );
    }
    write(moduleFile, moduleContent);
    writeln("Файл модуля создан: ", moduleFile);

    // 4. Генерация (или модификация) файла app.d в каталоге source
    writeln("Генерация файла приложения app.d...");
    string appFile = buildPath(sourceDir, "app.d");
    string imports;
    string registrations;
    // Используем SpanMode.depth, чтобы entry.name содержал относительный или абсолютный путь
    foreach (entry; dirEntries(sourceDir, SpanMode.depth))
    {
        if (!entry.isDir && entry.name.endsWith(".mod.d"))
        {
            writeln("Обрабатываем файл: ", entry.name);
            enum suffix = ".mod.d";
            // Получаем имя родительской директории и имя файла через std.path.baseName
            string parentDir = baseName(dirName(entry.name));
            string fileName = baseName(entry.name);
            // Удаляем суффикс .mod.d, чтобы получить базовое имя модуля
            string moduleBaseName = fileName[0 .. fileName.length - suffix.length];

            writeln("  Родительская директория: '", parentDir, "', базовое имя модуля: '", moduleBaseName, "'");
            // Если имя родительской директории совпадает с базовым именем файла, считаем модуль валидным
            if (parentDir == moduleBaseName)
            {
                imports ~= format("import %s.%s.mod;\n", moduleBaseName, moduleBaseName);
                string pascalName = toPascalCase(moduleBaseName);
                registrations ~= format("    { auto %sModule = new %sModule(); %sModule.registerRoutes(router); }\n", toLower(pascalName), pascalName, toLower(pascalName),);
                writeln("  Добавлен импорт для модуля: ", moduleBaseName);
            }
        }
    }

    if (imports.length == 0)
    {
        imports = "// Нет модулей для импорта\n";
        registrations = "    // Нет модулей для регистрации маршрутов\n";
    }

    string appContent = format(q{
module app;
import vibe.vibe;
%s

    /// Инициализация приложения.
    /// Здесь создаётся роутер и регистрируются маршруты сгенерированных модулей.
    URLRouter init() {
        auto router = new URLRouter;
            %s
        return router;
    }

    void main() {
        auto settings = new HTTPServerSettings;
        settings.port = 8080;
        auto router = init();
        listenHTTP(settings, router);
        runApplication();
    }
    }, imports, registrations);

    write(appFile, appContent);
    writeln("Файл приложения создан: ", appFile);

    writeln("Генерация завершена для модуля: ", moduleName, " с шаблоном: ", templateType);
}
